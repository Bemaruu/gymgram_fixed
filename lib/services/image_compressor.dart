import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  static Future<File> compress(
    File file, {
    int maxDimension = 1080,
    int quality = 72,
  }) async {
    return _compress(file, maxDimension: maxDimension, quality: quality);
  }

  /// Preset para vision IA: Gemini procesa internamente a ~768px,
  /// por lo que 896/70 es el punto donde no perdemos precision pero
  /// reducimos el payload base64 ~50% vs 1080/72.
  static Future<File> compressForVision(File file) =>
      _compress(file, maxDimension: 896, quality: 70);

  static Future<File> _compress(
    File file, {
    required int maxDimension,
    required int quality,
  }) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return file;
    final out = File(
      '${Directory.systemTemp.path}/gymgram_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(bytes);
    return out;
  }
}
