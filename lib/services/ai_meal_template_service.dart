import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_meal_template.dart';

/// Acceso al catálogo de recetas curadas (tabla ai_meal_templates).
///
/// Estas recetas alimentan al generador de planes de IA: la IA selecciona
/// y ordena recetas de esta DB en vez de generarlas desde cero (RAG).
///
/// Cuando se conecte la IA real, la Edge Function recibirá como contexto
/// los resultados de [getTemplatesForGoal] filtrados por el perfil del usuario.
class AiMealTemplateService {
  static final AiMealTemplateService instance = AiMealTemplateService._();
  AiMealTemplateService._();

  final _client = Supabase.instance.client;

  // Mapeo de los strings de objetivo de GymGram → valores de la tabla
  static const _goalMap = {
    'LOSE_WEIGHT': 'perder_grasa',
    'GAIN_MUSCLE': 'ganar_musculo',
    'MAINTAIN': 'mantener',
    'MAINTAIN_WEIGHT': 'mantener',
  };

  // Datos legacy del catálogo: algunas recetas usan 'mantenimiento' en vez de
  // 'mantener'. Sin esto, ~1/3 de las recetas quedaba oculta a usuarios MAINTAIN.
  static List<String> _objetivoSynonyms(String objetivo) {
    switch (objetivo) {
      case 'mantener':
        return const ['mantener', 'mantenimiento'];
      default:
        return [objetivo];
    }
  }

  /// Devuelve recetas filtradas para el objetivo del usuario.
  ///
  /// [goal] acepta los valores internos de GymGram: 'LOSE_WEIGHT', 'GAIN_MUSCLE', 'MAINTAIN'.
  /// [momento] filtra por momento del día ('desayuno', 'almuerzo', 'cena', 'colacion', etc.).
  /// [dificultad] filtra por 'Muy fácil', 'Normal' o 'Gourmet'.
  Future<List<AiMealTemplate>> getTemplatesForGoal(
    String goal, {
    String? momento,
    String? dificultad,
    List<String>? dificultades,
    int limit = 20,
  }) async {
    final objetivoDb = _goalMap[goal.toUpperCase()] ?? 'mantener';
    return _fetchTemplates(
      objetivo: objetivoDb,
      momento: momento,
      dificultad: dificultad,
      dificultades: dificultades,
      limit: limit,
    );
  }

  /// Devuelve recetas con filtros opcionales.
  ///
  /// [objetivo] valor directo de la tabla: 'perder_grasa', 'mantener', 'ganar_musculo'.
  /// [momento] momento del día: 'desayuno', 'almuerzo', 'cena', 'colacion', etc.
  /// [dificultad] nivel: 'Muy fácil', 'Normal', 'Gourmet'.
  Future<List<AiMealTemplate>> getTemplates({
    String? objetivo,
    String? momento,
    String? dificultad,
    List<String>? dificultades,
    int limit = 30,
  }) =>
      _fetchTemplates(
        objetivo: objetivo,
        momento: momento,
        dificultad: dificultad,
        dificultades: dificultades,
        limit: limit,
      );

  /// Busca recetas por nombre (búsqueda parcial, case-insensitive).
  Future<List<AiMealTemplate>> searchByName(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      final rows = await _client
          .from('ai_meal_templates')
          .select(
            'id, external_id, nombre, categoria_dificultad, modo_dieta, '
            'momento_dia, porcion_g, kcal, proteina_g, carbohidratos_g, '
            'grasas_g, fibra_g, sodio_mg, ingredientes_base, tags, '
            'objetivo_recomendado, costo_estimado_clp, nota_para_ia, '
            'source_url, confiabilidad, pais_origen',
          )
          .ilike('nombre', '%$q%')
          .eq('activo', true)
          .order('nombre')
          .limit(limit);
      return _parseRows(rows);
    } catch (e) {
      debugPrint('AiMealTemplateService.searchByName error: $e');
      return [];
    }
  }

  Future<List<AiMealTemplate>> _fetchTemplates({
    String? objetivo,
    String? momento,
    String? dificultad,
    List<String>? dificultades,
    required int limit,
  }) async {
    try {
      var query = _client
          .from('ai_meal_templates')
          .select(
            'id, external_id, nombre, categoria_dificultad, modo_dieta, '
            'momento_dia, porcion_g, kcal, proteina_g, carbohidratos_g, '
            'grasas_g, fibra_g, sodio_mg, ingredientes_base, tags, '
            'objetivo_recomendado, costo_estimado_clp, nota_para_ia, '
            'source_url, confiabilidad, pais_origen',
          )
          .eq('activo', true);

      // Filtro por objetivo: contiene el valor en el array.
      if (objetivo != null) {
        final synonyms = _objetivoSynonyms(objetivo);
        if (synonyms.length == 1) {
          query = query.contains('objetivo_recomendado', [synonyms.first]);
        } else {
          query = query.or(
            synonyms.map((s) => 'objetivo_recomendado.cs.{$s}').join(','),
          );
        }
      }

      // Filtro por momento del día: contiene el valor en el array
      if (momento != null) {
        query = query.contains('momento_dia', [momento]);
      }

      // Filtro por dificultad: una lista (inFilter) tiene prioridad sobre el
      // valor único, para poder permitir varios niveles a la vez.
      if (dificultades != null && dificultades.isNotEmpty) {
        query = query.inFilter('categoria_dificultad', dificultades);
      } else if (dificultad != null) {
        query = query.eq('categoria_dificultad', dificultad);
      }

      final rows = await query.order('external_id').limit(limit);
      return _parseRows(rows);
    } catch (e) {
      debugPrint('AiMealTemplateService._fetchTemplates error: $e');
      return [];
    }
  }

  List<AiMealTemplate> _parseRows(List<dynamic> rows) =>
      rows.map((r) => AiMealTemplate.fromMap(r as Map<String, dynamic>)).toList();
}
