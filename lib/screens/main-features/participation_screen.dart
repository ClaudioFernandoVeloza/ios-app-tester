import 'package:flutter/material.dart';
import 'package:pic_collector/screens/main-features/placeholder_screen.dart';

/// Participation tab: groups the user has been invited to.
class ParticipationScreen extends StatelessWidget {
  const ParticipationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Participation',
      icon: Icons.group,
    );
  }
}
