import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pic_collector/models/user_profile.dart';
import 'package:pic_collector/widgets/my_qr_code_button.dart';
import 'package:pic_collector/widgets/username_copy_button.dart';
import 'package:pic_collector/services/push_notification_service.dart';
import 'package:pic_collector/services/user_profile_service.dart';
import 'package:pic_collector/screens/auth/login_screen.dart';
import 'package:pic_collector/utils/formatters.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// Profile tab: the current user's profile with a logout button.
/// Shows Firstname Surname, @username and email from Firestore.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Shows a confirmation dialog, then signs the user out and
  /// returns to the [LoginScreen] (clearing the navigation stack).
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Remove this device's push token BEFORE clearing auth so the
              // uid is still available and the backend stops targeting us.
              try {
                await PushNotificationService.instance.clearCurrentUser();
              } catch (_) {
                // Best-effort: sign-out should never be blocked by this.
              }
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              showSnackBar(context, 'You have been logged out');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: user == null
              ? const Text('Not logged in')
              : StreamBuilder<UserProfile?>(
                  stream:
                      UserProfileService.instance.watchUserProfile(user.uid),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final hasName =
                        profile != null && profile.fullName.trim().isNotEmpty;
                    final username = profile?.username;
                    final hasUsername =
                        username != null && username.trim().isNotEmpty;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // --- User avatar ---
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.blue,
                          child: Text(
                            getInitials(profile, user.email),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- Firstname Surname ---
                        Text(
                          hasName ? profile.fullName : 'No name yet',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // --- Username ---
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                hasUsername ? '@$username' : 'No username',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: hasUsername
                                      ? Colors.blue
                                      : Colors.black38,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUsername) ...[
                              UsernameCopyButton(username: username.trim()),
                              MyQrCodeButton(username: username.trim()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // --- User email ---
                        Text(
                          user.email ?? 'No email',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // --- Logout button ---
                        SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLogoutDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

}
