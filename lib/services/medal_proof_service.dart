import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_compressor.dart';

/// Resultado de una verificacion por foto de medalla.
class MedalProofResult {
  final bool approved;
  final String reason;
  const MedalProofResult({required this.approved, required this.reason});
}

/// Sube la foto de prueba de una medalla al bucket privado y llama a la edge
/// function `verify-medal-photo`, que la verifica con IA y, si aprueba, la otorga.
class MedalProofService {
  static final MedalProofService instance = MedalProofService._();
  MedalProofService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  static const _bucket = 'medal-proofs';
  static const _maxBytes = 5 * 1024 * 1024;

  /// Sube [file] y solicita la verificacion de [badgeId].
  /// Lanza [Exception] con un mensaje legible si algo falla.
  Future<MedalProofResult> submitProof(String badgeId, File file) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado.');

    final size = await file.length();
    if (size > _maxBytes) {
      throw Exception('La imagen supera el límite de 5 MB.');
    }

    final compressed = await ImageCompressor.compress(file);
    final path = '$uid/${badgeId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await _client.storage.from(_bucket).upload(path, compressed);
    } catch (e) {
      debugPrint('MedalProofService upload error: $e');
      throw Exception('No se pudo subir la imagen. Intenta de nuevo.');
    }

    try {
      final res = await _client.functions.invoke(
        'verify-medal-photo',
        body: {'badge_id': badgeId, 'image_path': path},
      );
      final data = res.data;
      if (res.status == 200 && data is Map && data['ok'] == true) {
        return MedalProofResult(
          approved: data['approved'] == true,
          reason: (data['reason'] ?? '').toString(),
        );
      }
      final msg = (data is Map ? data['error'] : null)?.toString() ??
          'No se pudo verificar la foto.';
      throw Exception(msg);
    } catch (e) {
      debugPrint('verify-medal-photo invoke error: $e');
      if (e is Exception) rethrow;
      throw Exception('No se pudo verificar la foto. Intenta más tarde.');
    }
  }
}
