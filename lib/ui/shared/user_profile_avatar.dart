import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const UserProfileAvatar({
    super.key,
    this.imageUrl,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImageProvider(imageUrl!)
          : const AssetImage('assets/images/default_profile.png') as ImageProvider,
    );
  }
}
