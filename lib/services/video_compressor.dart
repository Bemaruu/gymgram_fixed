import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

class VideoCompressor {
  /// Comprime un video antes de subirlo para reducir storage/egress.
  /// Si la compresión falla o no reduce el tamaño, devuelve el archivo
  /// original para no romper el upload.
  static Future<File> compress(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final out = info?.file;
      if (out == null) return file;
      // Si por alguna razón quedó igual o más grande, usar el original.
      if (await out.length() >= await file.length()) return file;
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('VideoCompressor.compress error: $e');
      return file;
    }
  }
}
