import 'package:pic_collector/models/friend.dart';

/// A subgroup inside a group. Each subgroup has its own title,
/// description, members, and a collection of pictures.
class SubGroup {
  final String title;
  final String description;
  final List<Friend> members;
  final List<String> pictures;

  const SubGroup({
    required this.title,
    required this.description,
    required this.members,
    required this.pictures,
  });
}