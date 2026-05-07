import 'dart:io';

class Post {
  final File image;
  String caption;
  bool isLiked;
  int likes;

  Post({
    required this.image,
    required this.caption,
    this.isLiked = false,
    this.likes = 0,
  });
}