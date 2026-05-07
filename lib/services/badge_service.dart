import 'package:flutter/material.dart';
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
      condition: 'Registra un cambio físico medible y documentado.',
      rank: BadgeRank.diamante,
      difficulty: 9,
      imagePath: 'assets/medals/renacido.png',
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
    ),
    BadgeModel(
      id: 'runner',
      title: '5K GymGram',
      medalName: 'Runner',
      description: 'Corriste 5 kilómetros y lo demostraste.',
      condition: 'Corre 5km y sube la evidencia.',
      rank: BadgeRank.evento,
      difficulty: 5,
      imagePath: 'assets/medals/runner.png',
      isGlobalEvent: true,
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
      await _client.from('user_badges').upsert(
        {
          'user_id': userId,
          'badge_id': badgeId,
          'earned_at': DateTime.now().toIso8601String(),
          'progress': 1.0,
        },
        onConflict: 'user_id,badge_id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('awardBadge [$badgeId] error: $e');
    }
  }

  /// Actualiza el progreso (0.0–1.0) de una medalla aún no ganada.
  Future<void> updateBadgeProgress(
    String userId,
    String badgeId,
    double progress,
  ) async {
    try {
      await _client.from('user_badges').upsert(
        {
          'user_id': userId,
          'badge_id': badgeId,
          'progress': progress.clamp(0.0, 0.99),
          'earned_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,badge_id',
      );
    } catch (e) {
      debugPrint('updateBadgeProgress [$badgeId] error: $e');
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
        await _checkSevenConsecutiveDays(userId);
        break;
      case 'post_created':
        await awardBadge(userId, 'primera_publicacion');
        break;
      case 'like_given':
        final likeRows = await _client
            .from('likes')
            .select('id')
            .eq('user_id', userId);
        if ((likeRows as List).length >= 5) {
          await awardBadge(userId, 'social_inicial');
        }
        break;
      case 'water_logged':
        // TODO: consultar días con registro de agua y otorgar hidratado (7)
        break;
      case 'meal_plan_completed':
        // TODO: consultar días seguidos con plan y otorgar enfocado (5)
        break;
      case 'weight_logged':
        // TODO: consultar conteo de registros y otorgar evolucion_visible (5)
        break;
      case 'follower_gained':
        // TODO: consultar conteo de seguidores y otorgar referente (20)
        break;
      case 'challenge_completed':
        // Para uso manual por administración de eventos
        break;
    }
  }

  Future<void> _checkSevenConsecutiveDays(String userId) async {
    try {
      final result = await _client
          .from('workout_logs')
          .select('logged_at')
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(30);

      final dates = (result as List)
          .map((r) => DateTime.parse(r['logged_at'] as String))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      if (dates.length < 7) return;

      int consecutive = 1;
      for (int i = 1; i < dates.length; i++) {
        final diff = dates[i - 1].difference(dates[i]).inDays;
        if (diff == 1) {
          consecutive++;
          if (consecutive >= 7) {
            await awardBadge(userId, 'siete_dias_activo');
            return;
          }
        } else {
          consecutive = 1;
        }
      }
    } catch (e) {
      debugPrint('_checkSevenConsecutiveDays error: $e');
    }
  }

  // ── Lectura de medallas ───────────────────────────────────────────────────

  /// Devuelve todas las medallas ganadas por un usuario.
  Future<List<UserBadgeModel>> getUserBadges(String userId) async {
    try {
      final result = await _client
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .order('earned_at', ascending: false);
      return (result as List)
          .map((m) => UserBadgeModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getUserBadges error: $e');
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
      debugPrint('getMyFeaturedBadgeIds error: $e');
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
      debugPrint('getFeaturedBadgeIds error: $e');
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
      debugPrint('setFeaturedBadges error: $e');
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
}
