import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pic_collector/firebase_options.dart';
import 'package:pic_collector/screens/auth/login_screen.dart';
import 'package:pic_collector/screens/main-features/menu_orchestrator.dart';
import 'package:pic_collector/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must be registered before runApp; handles messages while the app is in
  // the background or terminated.
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // Permission + channel + token + tap routing. Safe to await before the UI
  // builds so a cold-start notification tap has its navigator ready.
  await PushNotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _checkingSession = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  /// Checks the persisted Firebase session so the app can skip the login
  /// screen when the user is still signed in ("remember me").
  ///
  /// Firebase Auth persists the session automatically (keystore/keychain on
  /// mobile, IndexedDB on web). Logging out calls `signOut()`, which clears
  /// the persisted session, so the login screen is shown again on the next
  /// launch.
  Future<void> _restoreSession() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;
    setState(() {
      _isLoggedIn = user != null;
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pic Collector',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _checkingSession
          ? const _AuthSplash()
          : (_isLoggedIn ? const MenuOrchestrator() : const LoginScreen()),
    );
  }
}

/// Splash shown while the persisted session is being restored.
class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pic Collector',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}