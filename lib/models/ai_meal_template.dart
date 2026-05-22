/// Receta curada del catálogo GymGram (tabla ai_meal_templates).
/// Los macros son por porción servida, no por 100g.
class AiMealTemplate {
  final String id;
  final String externalId;
  final String nombre;
  final String categoriaDificultad;
  final String modoDieta;
  final List<String> momentoDia;
  final int? porcionG;
  final int kcal;
  final double proteinaG;
  final double carbohidratosG;
  final double grasasG;
  final double? fibraG;
  final double? sodioMg;
  final String? ingredientesBase;
  final List<String> tags;
  // Valores: 'perder_grasa', 'mantener', 'ganar_musculo'
  final List<String> objetivoRecomendado;
  final int? costoEstimadoClp;
  final String? notaParaIa;
  final String? sourceUrl;
  final String confiabilidad;
  final String paisOrigen;

  const AiMealTemplate({
    required this.id,
    required this.externalId,
    required this.nombre,
    required this.categoriaDificultad,
    required this.modoDieta,
    required this.momentoDia,
    this.porcionG,
    required this.kcal,
    required this.proteinaG,
    required this.carbohidratosG,
    required this.grasasG,
    this.fibraG,
    this.sodioMg,
    this.ingredientesBase,
    required this.tags,
    required this.objetivoRecomendado,
    this.costoEstimadoClp,
    this.notaParaIa,
    this.sourceUrl,
    required this.confiabilidad,
    this.paisOrigen = 'CL',
  });

  bool get esMuyFacil => categoriaDificultad == 'Muy fácil';
  bool get esGourmet => categoriaDificultad == 'Gourmet';

  factory AiMealTemplate.fromMap(Map<String, dynamic> m) {
    List<String> toStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return AiMealTemplate(
      id: m['id'] as String,
      externalId: m['external_id'] as String,
      nombre: m['nombre'] as String,
      categoriaDificultad: m['categoria_dificultad'] as String,
      modoDieta: m['modo_dieta'] as String,
      momentoDia: toStringList(m['momento_dia']),
      porcionG: m['porcion_g'] as int?,
      kcal: (m['kcal'] as num).toInt(),
      proteinaG: toDouble(m['proteina_g']) ?? 0,
      carbohidratosG: toDouble(m['carbohidratos_g']) ?? 0,
      grasasG: toDouble(m['grasas_g']) ?? 0,
      fibraG: toDouble(m['fibra_g']),
      sodioMg: toDouble(m['sodio_mg']),
      ingredientesBase: m['ingredientes_base'] as String?,
      tags: toStringList(m['tags']),
      objetivoRecomendado: toStringList(m['objetivo_recomendado']),
      costoEstimadoClp: m['costo_estimado_clp'] as int?,
      notaParaIa: m['nota_para_ia'] as String?,
      sourceUrl: m['source_url'] as String?,
      confiabilidad: m['confiabilidad'] as String? ?? 'estimado',
      paisOrigen: m['pais_origen'] as String? ?? 'CL',
    );
  }
}
