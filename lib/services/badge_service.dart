import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge_model.dart';

/*
  ── SQL para crear la tabla user_badges en Supabase ─────────────────────────

  CREATE TABLE public.user_badges (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id       uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    badge_id      text NOT NULL,
    earned_at     timestamptz DEFAULT now() NOT NULL,
    progress      float8 DEFAULT 0 NOT NULL,
    is_featured   boolean DEFAULT false NOT NULL,
    featured_order integer,
    UNIQUE(user_id, badge_id)
  );

  ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

  -- Todos pueden leer medallas (para ver el perfil de otros)
  CREATE POLICY "select_all"  ON public.user_badges FOR SELECT USING (true);
  -- Solo el dueño puede insertar/actualizar/borrar
  CREATE POLICY "insert_own" ON public.user_badges FOR INSERT WITH CHECK (auth.uid() = user_id);
  CREATE POLICY "update_own" ON public.user_badges FOR UPDATE USING (auth.uid() = user_id);
  CREATE POLICY "delete_own" ON public.user_badges FOR DELETE USING (auth.uid() = user_id);

  ─────────────────────────────────────────────────────────────────────────────
*/

class BadgeService {
  static final BadgeService instance = BadgeService._();
  BadgeService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // ── Catálogo completo de medallas ─────────────────────────────────────────

  static const List<BadgeModel> catalog = [
    // ── BRONCE ──────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'primer_paso',
      title: 'Primer Paso',
      medalName: 'Primer Paso',
      description: 'El comienzo de tu camino en GymGram.',
      condition: 'Crea tu cuenta en GymGram.',
      rank: BadgeRank.bronce,
      difficulty: 1,
      imagePath: 'assets/medals/primer_paso.png',
    ),
    BadgeModel(
      id: 'perfil_completo',
      title: 'Perfil Completo',
      medalName: 'Identidad Definida',
      description: 'Tu perfil refleja quién eres. Ahora el mundo puede conocerte.',
      condition: 'Completa todos los datos de tu perfil.',
      rank: BadgeRank.bronce,
      difficulty: 2,
      imagePath: 'assets/medals/perfil_completo.png',
    ),
    BadgeModel(
      id: 'primera_rutina',
      title: 'Primera Rutina',
      medalName: 'Activado',
      description: 'El primer entrenamiento siempre es el más difícil.',
      condition: 'Completa 1 entrenamiento.',
      rank: BadgeRank.bronce,
      difficulty: 2,
      imagePath: 'assets/medals/primera_rutina.png',
    ),
    BadgeModel(
      id: 'siete_dias_activo',
      title: '7 Días Activo',
      medalName: 'Constancia Inicial',
      description: 'Una semana de disciplina. La constancia te hace mejor.',
      condition: 'Entrena 7 días seguidos.',
      rank: BadgeRank.bronce,
      difficulty: 3,
      imagePath: 'assets/medals/siete_dias_activo.png',
    ),
    BadgeModel(
      id: 'primera_publicacion',
      title: 'Primera Publicación',
      medalName: 'Me Mostré',
      description: 'Te animaste a compartir tu progreso con la comunidad.',
      condition: 'Sube tu primera publicación.',
      rank: BadgeRank.bronce,
      difficulty: 2,
      imagePath: 'assets/medals/primera_publicacion.png',
    ),
    BadgeModel(
      id: 'social_inicial',
      title: 'Social Inicial',
      medalName: 'Conectado',
      description: 'Te conectas con la comunidad y apoyas a otros.',
      condition: 'Da 5 likes a publicaciones.',
      rank: BadgeRank.bronce,
      difficulty: 1,
      imagePath: 'assets/medals/social_inicial.png',
    ),

    // ── PLATA ────────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'ritmo_constante',
      title: '14 días seguidos',
      medalName: 'Ritmo Constante',
      description: 'Dos semanas de entrenamiento continuo. El ritmo es tuyo.',
      condition: 'Entrena 2 semanas sin interrupción.',
      rank: BadgeRank.plata,
      difficulty: 4,
      imagePath: 'assets/medals/ritmo_constante.png',
    ),
    BadgeModel(
      id: 'evolucion_visible',
      title: 'Progreso físico',
      medalName: 'Evolución Visible',
      description: 'Registrar tu peso es el primer paso para ver los cambios.',
      condition: 'Registra tu peso 5 veces.',
      rank: BadgeRank.plata,
      difficulty: 4,
      imagePath: 'assets/medals/evolucion_visible.png',
    ),
    BadgeModel(
      id: 'mas_fuerte',
      title: 'Fuerza en aumento',
      medalName: 'Más Fuerte',
      description: 'Tu cuerpo responde. Los pesos suben.',
      condition: 'Sube los pesos de un ejercicio 3 veces.',
      rank: BadgeRank.plata,
      difficulty: 5,
      imagePath: 'assets/medals/mas_fuerte.png',
    ),
    BadgeModel(
      id: 'disciplinado',
      title: '10 entrenamientos',
      medalName: 'Disciplinado',
      description: 'Completar 10 rutinas demuestra que esto es un hábito.',
      condition: 'Completa 10 rutinas de entrenamiento.',
      rank: BadgeRank.plata,
      difficulty: 4,
      imagePath: 'assets/medals/disciplinado.png',
    ),
    BadgeModel(
      id: 'hidratado',
      title: 'Hidratación constante',
      medalName: 'Hidratado',
      description: 'El agua es el combustible del rendimiento.',
      condition: 'Registra tu consumo de agua 7 días.',
      rank: BadgeRank.plata,
      difficulty: 3,
      imagePath: 'assets/medals/hidratado.png',
    ),
    BadgeModel(
      id: 'enfocado',
      title: 'Comida controlada',
      medalName: 'Enfocado',
      description: 'La nutrición define el 70% de tus resultados.',
      condition: 'Sigue tu plan de alimentación 5 días.',
      rank: BadgeRank.plata,
      difficulty: 5,
      imagePath: 'assets/medals/enfocado.png',
    ),

    // ── ORO ──────────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'inquebrantable',
      title: '30 días seguidos',
      medalName: 'Inquebrantable',
      description: 'Un mes completo. Tu mente y cuerpo al máximo.',
      condition: 'Entrena 30 días consecutivos.',
      rank: BadgeRank.oro,
      difficulty: 7,
      imagePath: 'assets/medals/inquebrantable.png',
    ),
    BadgeModel(
      id: 'rompe_limites',
      title: 'Nuevo récord',
      medalName: 'Rompe Límites',
      description: 'Superaste tu propio límite. Eso es poder real.',
      condition: 'Establece un PR en cualquier ejercicio.',
      rank: BadgeRank.oro,
      difficulty: 7,
      imagePath: 'assets/medals/rompe_limites.png',
    ),
    BadgeModel(
      id: 'maquina',
      title: 'Quema total',
      medalName: 'Máquina',
      description: '10,000 kcal quemadas. Eres una máquina.',
      condition: 'Acumula 10.000 kcal quemadas en entrenamientos.',
      rank: BadgeRank.oro,
      difficulty: 6,
      imagePath: 'assets/medals/maquina.png',
    ),
    BadgeModel(
      id: 'precision_total',
      title: 'Rutina perfecta',
      medalName: 'Precisión Total',
      description: 'Una semana sin errores. Cero excusas.',
      condition: 'Completa todas las rutinas de una semana sin fallar.',
      rank: BadgeRank.oro,
      difficulty: 6,
      imagePath: 'assets/medals/precision_total.png',
    ),
    BadgeModel(
      id: 'inspiracion',
      title: 'Inspiración',
      medalName: 'Motivador',
      description: 'Tu contenido inspira a otros a moverse.',
      condition: 'Consigue 50 likes en una sola publicación.',
      rank: BadgeRank.oro,
      difficulty: 6,
      imagePath: 'assets/medals/inspiracion.png',
    ),
    BadgeModel(
      id: 'referente',
      title: 'Comunidad',
      medalName: 'Referente',
      description: 'La gente te sigue porque eres ejemplo.',
      condition: 'Alcanza 20 seguidores.',
      rank: BadgeRank.oro,
      difficulty: 6,
      imagePath: 'assets/medals/referente.png',
    ),

    // ── DIAMANTE ─────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'mente_y_cuerpo',
      title: '90 días seguidos',
      medalName: 'Mente y Cuerpo',
      description: 'Tres meses de disciplina absoluta. Eres otro.',
      condition: 'Mantén actividad constante 3 meses seguidos.',
      rank: BadgeRank.diamante,
      difficulty: 9,
      imagePath: 'assets/medals/mente_y_cuerpo.png',
    ),
    BadgeModel(
      id: 'bestia',
      title: 'Top rendimiento',
      medalName: 'Bestia',
      description: '50 entrenamientos. No hay otro nivel.',
      condition: 'Completa 50 entrenamientos totales.',
      rank: BadgeRank.diamante,
      difficulty: 8,
      imagePath: 'assets/medals/bestia.png',
    ),
    BadgeModel(
      id: 'renacido',
      title: 'Transformación real',
      medalName: 'Renacido',
      description: 'Tu cuerpo habla por sí solo. El cambio es visible.',
      condition: 'Sube una foto de tu progreso físico y la IA lo valida.',
      rank: BadgeRank.diamante,
      difficulty: 9,
      imagePath: 'assets/medals/renacido.png',
      requiresPhotoProof: true,
    ),
    BadgeModel(
      id: 'control_total',
      title: 'Rutina + dieta perfecta',
      medalName: 'Control Total',
      description: 'Treinta días de control absoluto. Fitness elevado.',
      condition: 'Completa 30 días combinando rutina y dieta perfectas.',
      rank: BadgeRank.diamante,
      difficulty: 9,
      imagePath: 'assets/medals/control_total.png',
    ),

    // ── ESPECIAL ─────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'beta_exclusiva',
      title: 'Beta Exclusiva',
      medalName: 'Génesis',
      description:
          'Fuiste parte de la primera etapa de GymGram. Una medalla única e irrepetible.',
      condition: 'Estar registrado en la beta de GymGram.',
      rank: BadgeRank.especial,
      difficulty: 0,
      imagePath: 'assets/medals/beta_exclusiva.png',
      isLimited: true,
    ),

    // ── EVENTO ───────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'conquistador',
      title: 'Cerro Challenge',
      medalName: 'Conquistador',
      description: 'Conquistaste el reto outdoor de GymGram.',
      condition: 'Sube una foto entrenando en el cerro del reto.',
      rank: BadgeRank.evento,
      difficulty: 6,
      imagePath: 'assets/medals/conquistador.png',
      isGlobalEvent: true,
      requiresPhotoProof: true,
    ),
    BadgeModel(
      id: 'runner',
      title: '5K GymGram',
      medalName: 'Runner',
      description: 'Corriste 5 kilómetros y lo demostraste.',
      condition: 'Corre 5km y sube la captura de tu app de running.',
      rank: BadgeRank.evento,
      difficulty: 5,
      imagePath: 'assets/medals/runner.png',
      isGlobalEvent: true,
      requiresPhotoProof: true,
    ),
    BadgeModel(
      id: 'full_mode',
      title: 'GymGram Week',
      medalName: 'Full Mode',
      description: 'Completaste todos los retos de la semana GymGram.',
      condition: 'Completa todos los retos de la semana activa.',
      rank: BadgeRank.evento,
      difficulty: 7,
      imagePath: 'assets/medals/full_mode.png',
      isGlobalEvent: true,
    ),
    BadgeModel(
      id: 'unido',
      title: 'Desafío Comunidad',
      medalName: 'Unido',
      description: 'Participaste en un reto global de la comunidad GymGram.',
      condition: 'Únete a un reto global activo.',
      rank: BadgeRank.evento,
      difficulty: 4,
      imagePath: 'assets/medals/unido.png',
      isGlobalEvent: true,
    ),

    // ── MINERAL ──────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'cobalto_core',
      title: 'Cobalto Core',
      medalName: 'Cobalto',
      description: 'Sesenta días de presencia constante. Solidez total.',
      condition: 'Mantente activo 60 días consecutivos.',
      rank: BadgeRank.mineral,
      difficulty: 8,
      imagePath: 'assets/medals/cobalto_core.png',
    ),
    BadgeModel(
      id: 'neon_vital',
      title: 'Neón Vital',
      medalName: 'Neón',
      description: 'Combinación perfecta de actividad física y vida social.',
      condition: 'Mantén actividad diaria y social simultáneamente.',
      rank: BadgeRank.mineral,
      difficulty: 7,
      imagePath: 'assets/medals/neon_vital.png',
    ),
    BadgeModel(
      id: 'obsidiana_mental',
      title: 'Obsidiana Mental',
      medalName: 'Obsidiana',
      description: 'Treinta días perfectos. Disciplina de acero.',
      condition: 'Completa 30 días sin fallar ninguna rutina.',
      rank: BadgeRank.mineral,
      difficulty: 9,
      imagePath: 'assets/medals/obsidiana_mental.png',
    ),

    // ── ESPECIAL ──────────────────────────────────────────────────────────────
    BadgeModel(
      id: 'embajador',
      title: 'Embajador',
      medalName: 'Embajador',
      description: 'Traes a la comunidad contigo. GymGram crece gracias a ti.',
      condition: 'Invita a 3 amigos con tu código de referido.',
      rank: BadgeRank.especial,
      difficulty: 5,
      imagePath: 'assets/medals/embajador.png',
    ),
  ];

  // ── Helpers del catálogo ──────────────────────────────────────────────────

  static BadgeModel? getBadgeById(String id) {
    try {
      return catalog.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<BadgeModel> getByRank(BadgeRank rank) =>
      catalog.where((b) => b.rank == rank).toList();

  // ── Operaciones Supabase ──────────────────────────────────────────────────

  /// Otorga una medalla al usuario. Silencioso si ya la tiene.
  Future<void> awardBadge(String userId, String badgeId) async {
    try {
      await _client.rpc('award_badge', params: {
        'p_user_id': userId,
        'p_badge_id': badgeId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('awardBadge [$badgeId] error: $e');
    }
  }

  /// Actualiza el progreso (0.0–1.0) de una medalla aún no ganada.
  Future<void> updateBadgeProgress(
    String userId,
    String badgeId,
    double progress,
  ) async {
    try {
      await _client.rpc('update_badge_progress', params: {
        'p_user_id': userId,
        'p_badge_id': badgeId,
        'p_progress': progress.clamp(0.0, 0.99),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('updateBadgeProgress [$badgeId] error: $e');
    }
  }

  /// Punto de entrada genérico para otorgar medallas según evento.
  /// Llama esto desde distintos lugares de la app cuando ocurre una acción.
  ///
  /// Ejemplos de eventType:
  ///   account_created, profile_completed, workout_completed,
  ///   post_created, like_given, water_logged, meal_plan_completed,
  ///   weight_logged, challenge_completed
  Future<void> checkAndAwardBadges(String userId, String eventType) async {
    switch (eventType) {
      case 'account_created':
        await awardBadge(userId, 'primer_paso');
        await awardBadge(userId, 'beta_exclusiva');
        break;
      case 'profile_completed':
        await awardBadge(userId, 'perfil_completo');
        break;
      case 'workout_completed':
        await awardBadge(userId, 'primera_rutina');
        await _checkWorkoutStreaksAndCounts(userId);
        break;
      case 'post_created':
        await awardBadge(userId, 'primera_publicacion');
        break;
      case 'like_given':
        try {
          final likeRows = await _client
              .from('likes')
              .select('id')
              .eq('user_id', userId);
          if ((likeRows as List).length >= 5) {
            await awardBadge(userId, 'social_inicial');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('checkAndAwardBadges [like_given] error: $e');
        }
        break;
      case 'water_logged':
        await _checkWaterStreak(userId);
        break;
      case 'meal_plan_completed':
        await _checkMealPlanDays(userId);
        break;
      case 'weight_logged':
        await _checkWeightLogs(userId);
        break;
      case 'follower_gained':
        // Solo efectivo si se ejecuta en la sesion del dueno. La via principal es
        // syncSelfBadges() al abrir el perfil propio (no se puede otorgar a terceros).
        await _checkFollowerCount(userId);
        break;
      case 'set_logged':
        await _checkStrengthBadges(userId);
        break;
      case 'challenge_completed':
        // Para uso manual por administración de eventos
        break;
    }
  }

  /// Otorga la medalla si [current] >= [target]; si no, guarda el progreso parcial.
  Future<void> _awardOrProgress(
    String userId,
    String badgeId,
    num current,
    num target,
  ) async {
    if (current >= target) {
      await awardBadge(userId, badgeId);
    } else {
      await updateBadgeProgress(userId, badgeId, current / target);
    }
  }

  /// Revisa el historial de entrenamientos y otorga (o actualiza progreso de)
  /// las medallas por conteo total y por racha de dias consecutivos.
  Future<void> _checkWorkoutStreaksAndCounts(String userId) async {
    try {
      final result = await _client
          .from('workout_logs')
          .select('logged_at')
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(400);

      final dates = (result as List)
          .map((r) => DateTime.parse(r['logged_at'] as String))
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      if (dates.isEmpty) return;

      // ── Conteo total de dias entrenados ──
      final total = dates.length;
      await _awardOrProgress(userId, 'disciplinado', total, 10);
      await _awardOrProgress(userId, 'bestia', total, 50);

      // ── Maquina: kcal quemadas (estimadas) ──
      // No registramos kcal reales; estimamos ~280 kcal por sesion de fuerza.
      final estimatedKcal = total * 280;
      await _awardOrProgress(userId, 'maquina', estimatedKcal, 10000);

      // ── Racha maxima de dias consecutivos ──
      int maxStreak = 1;
      int streak = 1;
      for (int i = 1; i < dates.length; i++) {
        final diff = dates[i - 1].difference(dates[i]).inDays;
        if (diff == 1) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
        } else if (diff > 1) {
          streak = 1;
        }
      }
      await _awardOrProgress(userId, 'siete_dias_activo', maxStreak, 7);
      await _awardOrProgress(userId, 'ritmo_constante', maxStreak, 14);
      await _awardOrProgress(userId, 'inquebrantable', maxStreak, 30);
      await _awardOrProgress(userId, 'cobalto_core', maxStreak, 60);
      await _awardOrProgress(userId, 'mente_y_cuerpo', maxStreak, 90);
    } catch (e) {
      if (kDebugMode) debugPrint('_checkWorkoutStreaksAndCounts error: $e');
    }
  }

  /// Recalcula y otorga las medallas que dependen de datos propios o de acciones
  /// de OTROS usuarios (seguidores, likes recibidos). Debe ejecutarse en la sesion
  /// del dueno (auth.uid() == userId), ya que award_badge solo permite auto-otorgar.
  /// Tambien sirve de backfill para usuarios que ya cumplian condiciones antiguas.
  Future<void> syncSelfBadges() async {
    final uid = _uid;
    if (uid == null) return;
    await _checkWorkoutStreaksAndCounts(uid);
    await _checkFollowerCount(uid);
    await _checkTopPostLikes(uid);
    await _checkStrengthBadges(uid);
    await _checkReferralCount(uid);
  }

  /// Medalla "Embajador": invitar a 3 amigos con tu código de referido.
  /// Usa la RPC my_referral_count (cuenta perfiles con referred_by = auth.uid()).
  Future<void> _checkReferralCount(String userId) async {
    if ((await _earnedAmong(userId, ['embajador'])).isNotEmpty) return;
    try {
      final res = await _client.rpc('my_referral_count');
      final count = res is int ? res : int.tryParse('$res') ?? 0;
      await _awardOrProgress(userId, 'embajador', count, 3);
    } catch (e) {
      if (kDebugMode) debugPrint('_checkReferralCount error: $e');
    }
  }

  /// Devuelve el subconjunto de [badgeIds] que el usuario ya tiene ganadas.
  /// Una sola query indexada (user_id, badge_id) para evitar recalcular medallas
  /// ya obtenidas en eventos de alta frecuencia.
  Future<Set<String>> _earnedAmong(String userId, List<String> badgeIds) async {
    try {
      final rows = await _client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId)
          .inFilter('badge_id', badgeIds);
      return (rows as List).map((r) => r['badge_id'] as String).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Medallas de fuerza basadas en set_logs / user_strength_records:
  ///  - rompe_limites: tener al menos 1 PR de fuerza registrado.
  ///  - mas_fuerte: subir el peso de un mismo ejercicio 3 veces (sesion a sesion).
  ///
  /// Se dispara en `set_logged` (cada serie). Para no bajar ~1000 filas de
  /// set_logs en cada serie, primero verificamos cuales medallas faltan y solo
  /// recalculamos esas. Una vez ganadas ambas, el evento cuesta 1 lookup barato.
  Future<void> _checkStrengthBadges(String userId) async {
    final earned = await _earnedAmong(userId, ['rompe_limites', 'mas_fuerte']);
    if (earned.length == 2) return; // ambas ya ganadas: nada que recalcular

    // Rompe Limites: cualquier PR registrado.
    if (!earned.contains('rompe_limites')) {
      try {
        final prs = await _client
            .from('user_strength_records')
            .select('id')
            .eq('user_id', userId)
            .limit(1);
        if ((prs as List).isNotEmpty) {
          await awardBadge(userId, 'rompe_limites');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('_checkStrengthBadges PR error: $e');
      }
    }

    // Mas Fuerte: 3 incrementos de peso en un mismo ejercicio.
    if (earned.contains('mas_fuerte')) return; // ya ganada: evita el fetch pesado
    try {
      final rows = await _client
          .from('set_logs')
          .select('exercise_name, weight_kg, logged_at')
          .eq('user_id', userId)
          .order('logged_at', ascending: true)
          .limit(1000);

      // Por ejercicio: peso maximo por dia, en orden cronologico.
      final Map<String, Map<String, double>> dailyMaxByExercise = {};
      for (final r in (rows as List)) {
        final name = r['exercise_name'] as String?;
        final w = (r['weight_kg'] as num?)?.toDouble();
        final loggedAt = r['logged_at'] as String?;
        if (name == null || w == null || loggedAt == null) continue;
        final day = loggedAt.substring(0, 10);
        final byDay = dailyMaxByExercise.putIfAbsent(name, () => {});
        if (w > (byDay[day] ?? 0)) byDay[day] = w;
      }

      int bestIncreases = 0;
      for (final byDay in dailyMaxByExercise.values) {
        final days = byDay.keys.toList()..sort();
        int increases = 0;
        double prev = -1;
        for (final d in days) {
          final w = byDay[d]!;
          if (prev >= 0 && w > prev) increases++;
          prev = w;
        }
        if (increases > bestIncreases) bestIncreases = increases;
      }
      await _awardOrProgress(userId, 'mas_fuerte', bestIncreases, 3);
    } catch (e) {
      if (kDebugMode) debugPrint('_checkStrengthBadges progression error: $e');
    }
  }

  /// Inspiracion: 50 likes en una sola publicacion propia.
  Future<void> _checkTopPostLikes(String userId) async {
    try {
      final rows = await _client
          .from('posts')
          .select('likes_count')
          .eq('user_id', userId)
          .order('likes_count', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return;
      final maxLikes = (rows.first['likes_count'] as num?)?.toInt() ?? 0;
      await _awardOrProgress(userId, 'inspiracion', maxLikes, 50);
    } catch (e) {
      if (kDebugMode) debugPrint('_checkTopPostLikes error: $e');
    }
  }

  // ── Lectura de medallas ───────────────────────────────────────────────────

  /// Devuelve todas las medallas ganadas por un usuario.
  Future<List<UserBadgeModel>> getUserBadges(String userId) async {
    try {
      final result = await _client
          .from('user_badges')
          .select('badge_id, progress, earned_at, is_featured, featured_order')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);
      return (result as List)
          .map((m) => UserBadgeModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getUserBadges error: $e');
      return [];
    }
  }

  /// Devuelve los IDs de las medallas destacadas del usuario actual, ordenadas.
  Future<List<String>> getMyFeaturedBadgeIds() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final result = await _client
          .from('user_badges')
          .select('badge_id, featured_order')
          .eq('user_id', uid)
          .eq('is_featured', true)
          .order('featured_order');
      return (result as List).map((m) => m['badge_id'] as String).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getMyFeaturedBadgeIds error: $e');
      return [];
    }
  }

  /// Devuelve los IDs de las medallas destacadas de cualquier usuario.
  Future<List<String>> getFeaturedBadgeIds(String userId) async {
    try {
      final result = await _client
          .from('user_badges')
          .select('badge_id, featured_order')
          .eq('user_id', userId)
          .eq('is_featured', true)
          .order('featured_order');
      return (result as List).map((m) => m['badge_id'] as String).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getFeaturedBadgeIds error: $e');
      return [];
    }
  }

  // ── Destacar medallas ─────────────────────────────────────────────────────

  /// Establece hasta 4 medallas como destacadas para el usuario actual.
  Future<void> setFeaturedBadges(List<String> badgeIds) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      // Quitar todas las destacadas actuales
      await _client
          .from('user_badges')
          .update({'is_featured': false, 'featured_order': null})
          .eq('user_id', uid);

      // Marcar las nuevas (max 4)
      final limited = badgeIds.take(4).toList();
      for (int i = 0; i < limited.length; i++) {
        await _client
            .from('user_badges')
            .update({'is_featured': true, 'featured_order': i})
            .eq('user_id', uid)
            .eq('badge_id', limited[i]);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('setFeaturedBadges error: $e');
    }
  }

  /// Verifica si un usuario tiene una medalla específica.
  Future<bool> hasBadge(String userId, String badgeId) async {
    try {
      final result = await _client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId)
          .eq('badge_id', badgeId)
          .maybeSingle();
      return result != null;
    } catch (_) {
      return false;
    }
  }

  // ── Checks privados para medallas de Plata ────────────────────────────────

  Future<void> _checkWaterStreak(String userId) async {
    try {
      final rows = await _client
          .from('water_logs')
          .select('target_date')
          .eq('user_id', userId)
          .gt('glasses_count', 0)
          .order('target_date', ascending: false)
          .limit(400);

      final dates = (rows as List)
          .map((r) => DateTime.parse(r['target_date'] as String))
          .toList();

      if (dates.isEmpty) return;

      int consecutive = 1;
      int maxConsecutive = 1;
      for (int i = 1; i < dates.length; i++) {
        final diff = dates[i - 1].difference(dates[i]).inDays;
        if (diff == 1) {
          consecutive++;
          if (consecutive > maxConsecutive) maxConsecutive = consecutive;
        } else {
          consecutive = 1;
        }
      }

      if (maxConsecutive >= 7) {
        await awardBadge(userId, 'hidratado');
      } else {
        await updateBadgeProgress(userId, 'hidratado', maxConsecutive / 7);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_checkWaterStreak error: $e');
    }
  }

  Future<void> _checkMealPlanDays(String userId) async {
    try {
      final rows = await _client
          .from('food_logs')
          .select('log_date')
          .eq('user_id', userId)
          .limit(200);
      final distinctDays = (rows as List)
          .map((r) => r['log_date'] as String)
          .toSet()
          .length;
      if (distinctDays >= 5) {
        await awardBadge(userId, 'enfocado');
      } else {
        await updateBadgeProgress(userId, 'enfocado', distinctDays / 5);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_checkMealPlanDays error: $e');
    }
  }

  Future<void> _checkWeightLogs(String userId) async {
    try {
      final rows = await _client
          .from('weight_logs')
          .select('id')
          .eq('user_id', userId);
      final count = (rows as List).length;
      if (count >= 5) {
        await awardBadge(userId, 'evolucion_visible');
      } else {
        await updateBadgeProgress(userId, 'evolucion_visible', count / 5);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_checkWeightLogs error: $e');
    }
  }

  Future<void> _checkFollowerCount(String userId) async {
    try {
      final res = await _client
          .from('follows')
          .select()
          .eq('following_id', userId)
          .count(CountOption.exact);
      final count = res.count;
      if (count >= 20) {
        await awardBadge(userId, 'referente');
      } else {
        await updateBadgeProgress(userId, 'referente', count / 20);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_checkFollowerCount error: $e');
    }
  }
}
