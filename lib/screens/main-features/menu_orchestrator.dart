import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pic_collector/models/red_dot.dart';
import 'package:pic_collector/models/user_profile.dart';
import 'package:pic_collector/screens/main-features/chat_screen.dart';
import 'package:pic_collector/screens/main-features/friends_screen.dart';
import 'package:pic_collector/screens/main-features/home_screen.dart';
import 'package:pic_collector/screens/main-features/participation_screen.dart';
import 'package:pic_collector/screens/main-features/friend_requests_screen.dart';

import 'package:pic_collector/screens/main-features/placeholder_screen.dart';
import 'package:pic_collector/screens/main-features/profile_screen.dart';
import 'package:pic_collector/services/friend_service.dart';

import 'package:pic_collector/utils/formatters.dart';

import '../../services/user_profile_service.dart';

/// Root screen that holds the bottom navigation (the "screen picker")
/// and renders the currently selected tab.
class MenuOrchestrator extends StatefulWidget {
  const MenuOrchestrator({super.key});

  @override
  State<MenuOrchestrator> createState() => _MenuOrchestratorState();
}

class _MenuOrchestratorState extends State<MenuOrchestrator> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    ParticipationScreen(),
    ChatScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  static const List<String> _titles = [
    'Pic Collector',
    'Participation',
    'Chat',
    'Friends',
    'Profile',
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Opens a drawer screen: the real Friend Requests inbox, or a
  /// placeholder for screens that are not implemented yet.
  void _openDrawerScreen(String title, IconData icon) {
    Navigator.pop(context); // close the drawer
    if (title == 'Friend Requests') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FriendRequestsScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceholderScreen(title: title, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Red dot while there are pending incoming friend requests, so the
        // user knows there is something to see in the drawer.
        leading: StreamBuilder<int>(
          stream: FriendService.instance.watchIncomingRequestCount(),
          builder: (context, snapshot) {
            final showDot = (snapshot.data ?? 0) > 0;
            return IconButton(
              icon: showDot
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: const [
                        Icon(Icons.menu, color: Colors.black87),
                        Positioned(top: 1, right: 1, child: RedDot(size: 9)),
                      ],
                    )
                  : const Icon(Icons.menu, color: Colors.black87),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            );
          },
        ),
        title: Text(
          _selectedIndex == 0 ? 'Pic Collector' : _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: GestureDetector(
                  onTap: () => _onDestinationSelected(4),
                  child: StreamBuilder<UserProfile?>(
                    stream: UserProfileService.instance
                        .watchUserProfile(user.uid),
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Text(
                          getInitials(profile, user.email),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _screens[_selectedIndex],
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // --- Drawer header ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue,
                child: const Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // --- Drawer items ---
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Friend Requests'),
                // Red dot while a request is waiting for an answer.
                trailing: StreamBuilder<int>(
                  stream: FriendService.instance.watchIncomingRequestCount(),
                  builder: (context, snapshot) {
                    if ((snapshot.data ?? 0) == 0) {
                      return const SizedBox.shrink();
                    }
                    return const RedDot();
                  },
                ),
                onTap: () => _openDrawerScreen(
                  'Friend Requests',
                  Icons.person_add_outlined,
                ),
              ),

              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Participation Requests'),
                onTap: () => _openDrawerScreen(
                  'Participation Requests',
                  Icons.group_add_outlined,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => _openDrawerScreen(
                  'Settings',
                  Icons.settings_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Participation',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}