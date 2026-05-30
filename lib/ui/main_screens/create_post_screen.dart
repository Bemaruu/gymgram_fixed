import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:io';

import '../../core/error_messages.dart';
import '../../services/analytics_service.dart';
import '../../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File? _selectedFile;
  String _mediaType = 'image';
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(PhosphorIconsDuotone.image, color: Colors.white),
              title: const Text('Imagen', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickImage(); },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsDuotone.videoCamera, color: Colors.white),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickVideo(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _selectedFile = File(file.path);
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (file != null) {
      setState(() {
        _selectedFile = File(file.path);
        _mediaType = 'video';
      });
    }
  }

  Future<void> _publish() async {
    if (_selectedFile == null || _isUploading) return;
    setState(() => _isUploading = true);
    try {
      final mediaUrl = await PostService.instance.uploadMedia(
        _selectedFile!,
        mediaType: _mediaType,
      );
      final caption = _captionController.text.trim();
      await PostService.instance.createPost(
        mediaUrl: mediaUrl,
        mediaType: _mediaType,
        caption: caption,
      );
      AnalyticsService.instance.postCreated(hasCaption: caption.isNotEmpty);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(humanizeError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Nueva publicación', style: TextStyle(color: Colors.white)),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFFF))),
            )
          else
            TextButton(
              onPressed: _publish,
              child: const Text('Publicar', style: TextStyle(color: Color(0xFF00BFFF), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showMediaPicker,
              child: Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: _selectedFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _mediaType == 'image'
                            ? Image.file(_selectedFile!, fit: BoxFit.cover)
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    color: Colors.black,
                                    child: const Icon(PhosphorIconsFill.videoCamera, size: 64, color: Colors.white30),
                                  ),
                                  const Icon(PhosphorIconsFill.playCircle, size: 56, color: Color(0xFF00BFFF)),
                                  Positioned(
                                    bottom: 12,
                                    child: Text(
                                      _selectedFile!.path.split('/').last,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIconsDuotone.imageSquare, size: 48, color: Colors.white24),
                            SizedBox(height: 8),
                            Text('Toca para seleccionar imagen o video', style: TextStyle(color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe una descripción...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00BFFF)),
                ),
              ),
              maxLines: 3,
              maxLength: 2200,
            ),
          ],
        ),
      ),
    );
  }
}
