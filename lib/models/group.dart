import 'package:pic_collector/models/friend.dart';
import 'package:flutter/material.dart';

/// Demo group model for the home screen.
class Group {
  final String name;
  final String description;
  final String category;
  final List<Friend> members;
  final DateTime createdAt;
  final IconData icon;
  final Color color;

  const Group({
    required this.name,
    required this.description,
    required this.category,
    required this.members,
    required this.createdAt,
    required this.icon,
    required this.color,
  });
}