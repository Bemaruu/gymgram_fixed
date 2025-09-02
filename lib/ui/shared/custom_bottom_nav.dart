import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/app_colors.dart';
import '../shared/user_profile_avatar.dart';
import '../../services/profile_photo_local.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String? profileImageUrl; // nueva propiedad opcional

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
  });

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
          radius: 12,
          backgroundImage: LocalProfilePhoto.imageFile != null
        ? FileImage(LocalProfilePhoto.imageFile!)
        : const AssetImage('assets/images/default_profile.png') as ImageProvider,
          ),
          label: 'Perfil',
        ),

      ],
    );
  }
}
