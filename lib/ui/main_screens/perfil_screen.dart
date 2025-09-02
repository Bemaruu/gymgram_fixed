import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/profile_photo_local.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String initialUsername;
  final String initialBio;

  const ProfileScreen({
    super.key,
    required this.initialUsername,
    required this.initialBio,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String username;
  late String bio;

  @override
  void initState() {
    super.initState();
    username = widget.initialUsername;
    bio = widget.initialBio;
  }

 void _navigateToEditProfile() async {
  final result = await Navigator.pushNamed(
    context,
    '/edit_profile',
    arguments: {
      'username': username,
      'bio': bio,
    },
  ) as Map<String, dynamic>?;

  if (result != null) {
    setState(() {
      username = result['username'] ?? username;
      bio = result['bio'] ?? bio;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: LocalProfilePhoto.imageFile != null
                  ? FileImage(LocalProfilePhoto.imageFile!)
                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '@$username',
            style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            bio.isNotEmpty ? bio : 'Esta es mi bio y me gusta GymGram 💪🏽',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Column(
                children: [
                  Text('0', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  Text('GymFriends', style: TextStyle(color: Colors.black54)),
                ],
              ),
              Column(
                children: [
                  Text('0', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  Text('Siguiendo', style: TextStyle(color: Colors.black54)),
                ],
              ),
              Column(
                children: [
                  Text('0', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  Text('Publicaciones', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Aún no has subido publicaciones 💤',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
