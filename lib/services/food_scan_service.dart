import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_compressor.dart';

/// Un alimento estimado por la IA a partir de una foto. Los valores son
/// para [grams]; al editar la porcion se reescalan proporcionalmente.
class ScannedFood {
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double confidence;

  const ScannedFood({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidence,
  });

  factory ScannedFood.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) {
      final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
      return n.isFinite ? n : 0;
    }

    return ScannedFood(
      name: (m['name'] ?? '').toString(),
      grams: d(m['grams']),
      kcal: d(m['kcal']),
      protein: d(m['protein_g']),
      carbs: d(m['carbs_g']),
      fat: d(m['fat_g']),
      confidence: d(m['confidence']),
    );
  }

  /// Mapa listo para `FoodService.logPlanComponent`, reescalado a [newGrams].
  Map<String, dynamic> toLogComponent(double newGrams) {
    final f = grams > 0 ? newGrams / grams : 1.0;
    return {
      'name': name,
      'grams': newGrams,
      'calories': kcal * f,
      'protein': protein * f,
      'carbs': carbs * f,
      'fats': fat * f,
    };
  }
}

class ScanResult {
  final List<ScannedFood> items;
  final List<String> allergyWarnings;

  /// Mensaje opcional del backend (ej: "no detectamos comida en la foto").
  final String? message;

  const ScanResult({
    required this.items,
    required this.allergyWarnings,
    this.message,
  });

  bool get isEmpty => items.isEmpty;
}

/// Excepción tipada para que la UI pueda diferenciar:
/// - `nsfw_violation` → strike, advertencia roja
/// - `suspended` → cuenta suspendida temporalmente
/// - genérico → SnackBar normal
class ScanException implements Exception {
  final String code;
  final String message;
  final DateTime? suspendedUntil;

  const ScanException({
    required this.code,
    required this.message,
    this.suspendedUntil,
  });

  bool get isNsfw => code == 'nsfw_violation';
  bool get isSuspended => code == 'suspended';

  @override
  String toString() => message;
}

/// Escanea una foto de comida con la edge function `scan-food` (Gemini).
/// Solo Plus/Premium (el tier lo valida el backend). La foto se envia como
/// base64 y NO se guarda en el servidor.
class FoodScanService {
  static final FoodScanService instance = FoodScanService._();
  FoodScanService._();

  final _client = Supabase.instance.client;

  /// Comprime [image], la manda a la IA y devuelve los alimentos estimados.
  /// Lanza [ScanException] con código si el backend rechaza por moderación.
  Future<ScanResult> scan(File image) async {
    final compressed = await ImageCompressor.compressForVision(image);
    final bytes = await compressed.readAsBytes();
    final b64 = base64Encode(bytes);

    try {
      final res = await _client.functions.invoke(
        'scan-food',
        body: {'image_base64': b64, 'mime_type': 'image/jpeg'},
      );
      final data = res.data;

      if (data is Map && data['ok'] == true) {
        final raw = (data['items'] as List?) ?? const [];
        final items = raw
            .whereType<Map>()
            .map((m) => ScannedFood.fromMap(m.cast<String, dynamic>()))
            .where((f) => f.name.isNotEmpty && f.grams > 0)
            .toList();
        final warnings = ((data['allergy_warnings'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        return ScanResult(
          items: items,
          allergyWarnings: warnings,
          message: data['message']?.toString(),
        );
      }

      // ok=false → puede traer code para diferenciar (nsfw/suspended/etc).
      final code = (data is Map ? data['code'] : null)?.toString() ?? 'error';
      final msg = (data is Map ? data['error'] : null)?.toString() ??
          'No se pudo analizar la foto.';
      final until = (data is Map ? data['suspended_until'] : null);
      throw ScanException(
        code: code,
        message: msg,
        suspendedUntil: until is String ? DateTime.tryParse(until) : null,
      );
    } on ScanException {
      rethrow;
    } catch (e) {
      debugPrint('scan-food invoke error: $e');
      throw const ScanException(
        code: 'error',
        message: 'No se pudo analizar la foto. Intenta más tarde.',
      );
    }
  }
}
