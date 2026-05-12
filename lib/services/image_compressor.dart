import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  static Future<File> compress(
    File file, {
    int maxDimension = 1080,
    int quality = 72,
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
