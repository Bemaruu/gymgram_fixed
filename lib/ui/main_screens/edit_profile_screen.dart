import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_photo_local.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentUsername;
  final String currentBio;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    required this.currentBio,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _image;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _image = file;
      });
      LocalProfilePhoto.setImage(file);
    }
  }

  void _saveChanges() {
    Navigator.pop(context, {
      'username': _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : widget.currentUsername,
      'bio': _bioController.text.trim().isNotEmpty
          ? _bioController.text.trim()
          : widget.currentBio,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _image != null
                    ? FileImage(_image!)
                    : LocalProfilePhoto.imageFile != null
                        ? FileImage(LocalProfilePhoto.imageFile!)
                        : const AssetImage('assets/images/default_profile.png') as ImageProvider,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Nombre de usuario',
                hintText: '@${widget.currentUsername}',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Biografía',
                hintText: widget.currentBio,
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Guardar Cambios'),
            )
          ],
        ),
      ),
    );
  }
}
