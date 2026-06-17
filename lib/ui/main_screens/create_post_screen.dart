import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
  // Carrusel de imágenes (máx PostService.maxCarouselImages) o un único video.
  final List<File> _images = [];
  File? _video;

  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final _previewController = PageController();

  bool _isUploading = false;
  String? _progressLabel;
  int _previewIndex = 0;

  static int get _maxImages => PostService.maxCarouselImages;

  bool get _hasMedia => _images.isNotEmpty || _video != null;

  @override
  void dispose() {
    _captionController.dispose();
    _previewController.dispose();
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
              leading: const Icon(PhosphorIconsRegular.images, color: Colors.white),
              title: const Text('Fotos', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Hasta 10 en un carrusel', style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () { Navigator.pop(context); _pickImages(); },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.videoCamera, color: Colors.white),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickVideo(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      _snack('Llegaste al máximo de $_maxImages fotos.');
      return;
    }
    final List<XFile> files = await _picker.pickMultiImage(limit: remaining);
    if (files.isEmpty) return;
    final toAdd = files.take(remaining).map((f) => File(f.path)).toList();
    final overflow = files.length > remaining;
    setState(() {
      _video = null; // imágenes y video son excluyentes
      _images.addAll(toAdd);
      _previewIndex = _images.length - toAdd.length;
    });
    if (overflow) _snack('Solo se agregaron $remaining; el límite es $_maxImages.');
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (file != null) {
      setState(() {
        _images.clear();
        _video = File(file.path);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_previewIndex >= _images.length) {
        _previewIndex = _images.isEmpty ? 0 : _images.length - 1;
      }
    });
    if (_images.isNotEmpty && _previewController.hasClients) {
      _previewController.jumpToPage(_previewIndex);
    }
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
      _previewIndex = newIndex;
    });
    if (_previewController.hasClients) _previewController.jumpToPage(newIndex);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _publish() async {
    if (!_hasMedia || _isUploading) return;
    setState(() => _isUploading = true);
    try {
      final caption = _captionController.text.trim();

      if (_video != null) {
        final url = await PostService.instance
            .uploadMedia(_video!, mediaType: 'video');
        await PostService.instance.createPost(
          mediaUrl: url,
          mediaType: 'video',
          caption: caption,
        );
      } else {
        final media = <({String url, String type})>[];
        for (var i = 0; i < _images.length; i++) {
          if (mounted) {
            setState(() => _progressLabel = 'Subiendo ${i + 1}/${_images.length}');
          }
          final url = await PostService.instance
              .uploadMedia(_images[i], mediaType: 'image');
          media.add((url: url, type: 'image'));
        }
        await PostService.instance
            .createPostWithMedia(media: media, caption: caption);
      }

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
      if (mounted) setState(() { _isUploading = false; _progressLabel = null; });
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
              onPressed: _hasMedia ? _publish : null,
              child: Text(
                'Publicar',
                style: TextStyle(
                  color: _hasMedia ? const Color(0xFF00BFFF) : Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPreview(),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildThumbnailStrip(),
          ],
          if (_progressLabel != null) ...[
            const SizedBox(height: 8),
            Text(_progressLabel!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
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
    );
  }

  Widget _buildPreview() {
    if (!_hasMedia) {
      return GestureDetector(
        onTap: _showMediaPicker,
        child: Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsRegular.imagesSquare, size: 48, color: Colors.white24),
                SizedBox(height: 8),
                Text('Toca para seleccionar fotos o video', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    if (_video != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 280,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(PhosphorIconsFill.videoCamera, size: 64, color: Colors.white30),
                ),
              ),
              const Icon(PhosphorIconsFill.playCircle, size: 56, color: Color(0xFF00BFFF)),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  _video!.path.split(Platform.pathSeparator).last,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Carrusel de imágenes con contador.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _previewController,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _previewIndex = i),
              itemBuilder: (_, i) => Image.file(
                _images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            if (_images.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_previewIndex + 1}/${_images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (_images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_images.length, (i) {
                    final active = i == _previewIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 8 : 6,
                      height: active ? 8 : 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorder: _reorderImages,
              itemCount: _images.length,
              itemBuilder: (context, i) {
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(_images[i].path),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _images[i],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeImage(i),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_images.length < _maxImages)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(PhosphorIconsRegular.plus, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
