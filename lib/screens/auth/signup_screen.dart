import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pic_collector/services/push_notification_service.dart';
import 'package:pic_collector/services/user_profile_service.dart';
import 'package:pic_collector/utils/user_notice.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _signUpFirstNameController = TextEditingController();
  final _signUpSurnameController = TextEditingController();
  final _signUpUsernameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  bool _isLoading = false;

  /// Usernames: 3-20 chars, letters, numbers and underscores only.
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  /// Names: 2-30 chars, letters (incl. accents), spaces and hyphens only.
  static final RegExp _nameRegExp = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F' -]{2,30}$");

  @override
  void dispose() {
    _signUpFirstNameController.dispose();
    _signUpSurnameController.dispose();
    _signUpUsernameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final firstName = _signUpFirstNameController.text.trim();
    final surname = _signUpSurnameController.text.trim();
    final username = _signUpUsernameController.text.trim();
    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text.trim();
    User? createdUser;

    if (firstName.isEmpty ||
        surname.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showSnackBar(context, 'Please fill all the fields');
      return;
    }

    if (!_nameRegExp.hasMatch(firstName)) {
      showSnackBar(
        context,
        'Firstname must be 2-30 letters (spaces and - allowed)',
      );
      return;
    }

    if (!_nameRegExp.hasMatch(surname)) {
      showSnackBar(
        context,
        'Surname must be 2-30 letters (spaces and - allowed)',
      );
      return;
    }

    if (!_usernameRegExp.hasMatch(username)) {
      showSnackBar(
        context,
        'Username must be 3-20 characters: letters, numbers or _ only',
      );
      return;
    }

    if (password.length < 6) {
      showSnackBar(context, 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Pre-check: the username must be free before we touch Firebase Auth
      // so we never leave an orphan auth account behind.
      if (!await UserProfileService.instance.isUsernameAvailable(username)) {
        if (!mounted) return;
        showSnackBar(context, 'Username already taken, please choose another');
        return;
      }

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Account creation failed');
      }
      createdUser = user;

      // Save the chosen username on the Firebase account so it persists
      // across sessions.
      await user.updateDisplayName(username);
      await user.reload();

      // Store the full profile (username, firstname, surname) in Firestore.
      try {
        await UserProfileService.instance.createUserProfile(
          user: user,
          username: username,
          firstName: firstName,
          surname: surname,
        );
      } on FirebaseException catch (e) {
        // The account exists but the profile doc failed (e.g. Firestore not
        // enabled yet). Inform the user instead of failing silently.
        if (mounted) {
          showSnackBar(
            context,
            'Account created, but saving the profile failed: '
            '${e.message ?? e.code}',
          );
        }
      }

      // Save this device's FCM token so friend-request pushes reach it.
      await PushNotificationService.instance.attachToCurrentUser();

      if (mounted) {
        showSnackBar(context, 'Account created successfully!');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        default:
          message = e.message ?? 'Sign up failed';
      }
      if (mounted) showSnackBar(context, message);
    } on UsernameTakenException catch (e) {
      // Double safety: a race between the pre-check and the transaction made
      // this username unavailable. Delete the auth account so no orphan user
      // remains, then ask the user to pick a different name.
      try {
        await createdUser?.delete();
      } catch (_) {
        // Best-effort cleanup: user will need to retry with another name.
      }
      if (mounted) showSnackBar(context, '${e.username} is already taken');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join Pic Collector and start sharing',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 48),

                // --- Firstname ---
                TextField(
                  controller: _signUpFirstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Firstname',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // --- Surname ---
                TextField(
                  controller: _signUpSurnameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Surname',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // --- Username ---
                TextField(
                  controller: _signUpUsernameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Username',
                    helperText: '3-20 characters: letters, numbers or _',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _signUpEmailController,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _signUpPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
