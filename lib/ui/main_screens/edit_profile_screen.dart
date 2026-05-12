import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_photo_local.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';

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

  File? _localImage;
  String? _remoteAvatarUrl;
  bool _uploadingAvatar = false;
  bool _saving = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAvatar();
  }

  Future<void> _loadCurrentAvatar() async {
    final profile = await SupabaseService.instance.getRawMyProfile();
    if (mounted) {
      setState(() {
        _remoteAvatarUrl = profile?['avatar_url'] as String?;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _localImage = file;
      _uploadingAvatar = true;
    });
    LocalProfilePhoto.setImage(file);

    try {
      final url = await SupabaseService.instance.uploadAvatar(file);
      if (mounted) setState(() { _remoteAvatarUrl = url; _uploadingAvatar = false; });
    } catch (e) {
      debugPrint('uploadAvatar error: $e');
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la foto')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta accion es permanente. Se eliminaran tu perfil y todos tus datos. '
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await AuthService().deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    final newUsername = _usernameController.text.trim();
    final newBio = _bioController.text.trim();

    try {
      await SupabaseService.instance.updateProfile(
        username: newUsername.isNotEmpty ? newUsername : null,
        bio: newBio.isNotEmpty ? newBio : null,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, {
      'username': newUsername.isNotEmpty ? newUsername : widget.currentUsername,
      'bio': newBio.isNotEmpty ? newBio : widget.currentBio,
      'avatarUrl': _remoteAvatarUrl,
    });
  }

  ImageProvider _avatarProvider() {
    if (_localImage != null) return FileImage(_localImage!);
    if (_remoteAvatarUrl != null && _remoteAvatarUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(_remoteAvatarUrl!);
    }
    if (LocalProfilePhoto.imageFile != null) return FileImage(LocalProfilePhoto.imageFile!);
    return const AssetImage('assets/images/default_profile.png');
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
              onTap: _uploadingAvatar ? null : _pickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarProvider(),
                  ),
                  if (_uploadingAvatar)
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.black45,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  if (!_uploadingAvatar)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                ],
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
              onPressed: (_saving || _uploadingAvatar || _deletingAccount) ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Guardar Cambios'),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: (_saving || _uploadingAvatar || _deletingAccount)
                  ? null
                  : _confirmDeleteAccount,
              child: _deletingAccount
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                    )
                  : const Text(
                      'Eliminar cuenta',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
