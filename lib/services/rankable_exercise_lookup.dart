import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo simple de un ejercicio rankeable cacheado.
class RankableExercise {
  final String id;
  final String nameEs;
  final String slug;
  final String movementPattern;

  const RankableExercise({
    required this.id,
    required this.nameEs,
    required this.slug,
    required this.movementPattern,
  });

  factory RankableExercise.fromMap(Map<String, dynamic> m) {
    return RankableExercise(
      id: m['id'] as String,
      nameEs: m['name_es'] as String? ?? '',
      slug: m['slug'] as String? ?? '',
      movementPattern: m['movement_pattern'] as String? ?? 'other',
    );
  }
}

/// Singleton con cache en memoria de los ejercicios marcados como
/// counts_for_ranked = true en exercise_catalog. Permite resolver el
/// exercise_id + movement_pattern correcto a partir del nombre libre
/// de un ejercicio en una rutina del usuario.
class RankableExerciseLookup {
  RankableExerciseLookup._();
  static final RankableExerciseLookup instance = RankableExerciseLookup._();

  final _client = Supabase.instance.client;
  List<RankableExercise>? _cache;
  Future<List<RankableExercise>>? _inflight;

  /// Devuelve la lista completa de ejercicios rankeables. Cache en memoria,
  /// vive lo que vive el proceso. Si dos llamadas concurrentes ocurren se
  /// comparte el mismo Future.
  Future<List<RankableExercise>> getAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final inflight = _inflight;
    if (inflight != null) return inflight;

    final future = _fetch();
    _inflight = future;
    try {
      final list = await future;
      _cache = list;
      return list;
    } finally {
      _inflight = null;
    }
  }

  Future<List<RankableExercise>> _fetch() async {
    try {
      final rows = await _client
          .from('exercise_catalog')
          .select('id, name_es, slug, movement_pattern')
          .eq('counts_for_ranked', true);
      final list = (rows as List)
          .map((r) => RankableExercise.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      return list;
    } catch (e) {
      debugPrint('RankableExerciseLookup fetch error: $e');
      return const [];
    }
  }

  /// Intenta resolver un nombre de ejercicio libre contra el catalogo
  /// rankeable. Devuelve null si no hay match confiable.
  Future<RankableExercise?> findMatch(String exerciseName) async {
    if (exerciseName.trim().isEmpty) return null;
    final all = await getAll();
    if (all.isEmpty) return null;

    final needle = _normalize(exerciseName);
    if (needle.isEmpty) return null;

    // 1) match exacto por nombre normalizado o slug
    for (final ex in all) {
      if (_normalize(ex.nameEs) == needle) return ex;
      if (_normalize(ex.slug.replaceAll('-', ' ')) == needle) return ex;
    }

    // 2) contiene / es contenido (ambos lados, longitud minima 4 para evitar
    //    matches absurdos como "press" -> cualquier press)
    if (needle.length >= 4) {
      for (final ex in all) {
        final hay = _normalize(ex.nameEs);
        if (hay.contains(needle) || needle.contains(hay)) return ex;
      }
    }

    // 3) overlap de palabras >= 80% (basado en el conjunto mas chico)
    final needleWords = _wordsOf(needle);
    if (needleWords.isEmpty) return null;
    RankableExercise? best;
    double bestScore = 0;
    for (final ex in all) {
      final hayWords = _wordsOf(_normalize(ex.nameEs));
      if (hayWords.isEmpty) continue;
      final inter = needleWords.intersection(hayWords);
      if (inter.isEmpty) continue;
      final minSize = needleWords.length < hayWords.length
          ? needleWords.length
          : hayWords.length;
      final score = inter.length / minSize;
      if (score >= 0.8 && score > bestScore) {
        bestScore = score;
        best = ex;
      }
    }
    return best;
  }

  /// Invalidar cache (util para tests o tras admin updates).
  void invalidate() {
    _cache = null;
  }

  // ---------- helpers ----------

  static String _normalize(String s) {
    var x = s.toLowerCase().trim();
    // remover acentos comunes en español
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final b = StringBuffer();
    for (final ch in x.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    x = b.toString();
    // colapsar espacios y eliminar puntuacion suave
    x = x.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  static Set<String> _wordsOf(String normalized) {
    // descartar stopwords cortas y conectores
    const stop = {'de', 'la', 'el', 'con', 'en', 'y', 'a', 'al', 'del', 'los', 'las'};
    return normalized
        .split(' ')
        .where((w) => w.length >= 3 && !stop.contains(w))
        .toSet();
  }
}
