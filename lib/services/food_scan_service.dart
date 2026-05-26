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

  /// Nombres de items que coinciden con alguna alergia del usuario.
  final List<String> allergyWarnings;

  const ScanResult({required this.items, required this.allergyWarnings});

  bool get isEmpty => items.isEmpty;
}

/// Escanea una foto de comida con la edge function `scan-food` (Gemini).
/// Solo Plus/Premium (el tier lo valida el backend). La foto se envia como
/// base64 y NO se guarda en el servidor.
class FoodScanService {
  static final FoodScanService instance = FoodScanService._();
  FoodScanService._();

  final _client = Supabase.instance.client;

  /// Comprime [image], la manda a la IA y devuelve los alimentos estimados.
  /// Lanza [Exception] con un mensaje legible si algo falla.
  Future<ScanResult> scan(File image) async {
    final compressed = await ImageCompressor.compress(image);
    final bytes = await compressed.readAsBytes();
    final b64 = base64Encode(bytes);

    try {
      final res = await _client.functions.invoke(
        'scan-food',
        body: {'image_base64': b64, 'mime_type': 'image/jpeg'},
      );
      final data = res.data;
      if (res.status == 200 && data is Map && data['ok'] == true) {
        final raw = (data['items'] as List?) ?? const [];
        final items = raw
            .whereType<Map>()
            .map((m) => ScannedFood.fromMap(m.cast<String, dynamic>()))
            .where((f) => f.name.isNotEmpty && f.grams > 0)
            .toList();
        final warnings = ((data['allergy_warnings'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        return ScanResult(items: items, allergyWarnings: warnings);
      }
      final msg = (data is Map ? data['error'] : null)?.toString() ??
          'No se pudo analizar la foto.';
      throw Exception(msg);
    } catch (e) {
      debugPrint('scan-food invoke error: $e');
      if (e is Exception) rethrow;
      throw Exception('No se pudo analizar la foto. Intenta más tarde.');
    }
  }
}
