import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/app_colors.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String? profileImageUrl;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
  });

  ImageProvider _avatarImage() {
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(profileImageUrl!);
    }
    return const AssetImage('assets/images/default_profile.png');
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Rutina',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.heart_fill),
          label: 'Dieta',
        ),
        BottomNavigationBarItem(
          icon: CircleAvatar(
            radius: 13,
            backgroundImage: _avatarImage(),
            backgroundColor: Colors.grey.shade200,
          ),
          label: 'Perfil',
        ),
      ],
    );
  }
}
