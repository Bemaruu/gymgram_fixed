/// Mapea un grupo muscular + nombre de ejercicio a un movement_pattern
/// canonico para set_logs / ranked. Devuelve siempre un valor valido del
/// CHECK constraint: push_horizontal, push_vertical, pull_horizontal,
/// pull_vertical, squat, hinge, other.
String mapMuscleGroupToMovementPattern(
  String? muscleGroup,
  String exerciseName,
) {
  final m = (muscleGroup ?? '').toLowerCase().trim();
  final n = exerciseName.toLowerCase().trim();

  bool any(String hay, List<String> needles) {
    for (final k in needles) {
      if (hay.contains(k)) return true;
    }
    return false;
  }

  final isChest = any(m, ['pecho', 'chest']);
  final isShoulder = any(m, ['hombro', 'shoulder', 'deltoide']);
  final isBack = any(m, ['espalda', 'back', 'dorsal', 'lat']);
  final isLeg = any(m, [
    'pierna',
    'leg',
    'cuad',
    'quad',
    'femoral',
    'hamstring',
    'gluteo',
    'glúteo',
    'glute',
    'cadena posterior',
  ]);

  final mentionsBench = any(n, ['banca', 'bench']);
  final mentionsHorizontalPress = any(n, [
    'press de banca',
    'press inclinado',
    'press declinado',
    'press de pecho',
    'press pecho',
    'bench press',
    'chest press',
  ]);
  final mentionsPushup = any(n, ['flexion', 'flexión', 'push-up', 'pushup', 'push up']);
  final mentionsVerticalPress = any(n, [
    'press militar',
    'press de hombro',
    'press hombros',
    'press arnold',
    'press overhead',
    'overhead press',
    'shoulder press',
    'military press',
    'pike',
  ]);
  final mentionsRow = any(n, ['remo', 'row', 't-bar', 't bar']);
  final mentionsPullVertical = any(n, [
    'dominada',
    'pull-up',
    'pullup',
    'pull up',
    'chin-up',
    'chinup',
    'chin up',
    'jalon',
    'jalón',
    'lat pulldown',
    'pulldown',
  ]);
  final mentionsSquat = any(n, [
    'sentadilla',
    'squat',
    'goblet',
    'hack squat',
    'prensa',
    'leg press',
    'zancada',
    'lunge',
    'step-up',
    'step up',
    'bulgara',
    'búlgara',
  ]);
  final mentionsHinge = any(n, [
    'peso muerto',
    'deadlift',
    'rdl',
    'hip thrust',
    'hip-thrust',
    'puente',
    'good morning',
    'nordic',
  ]);

  // --- Push horizontal ---
  if ((isChest && (mentionsHorizontalPress || mentionsBench || mentionsPushup))) {
    return 'push_horizontal';
  }
  if (mentionsHorizontalPress || (mentionsPushup && !isShoulder)) {
    return 'push_horizontal';
  }

  // --- Push vertical ---
  if (isShoulder && mentionsVerticalPress) return 'push_vertical';
  if (mentionsVerticalPress) return 'push_vertical';

  // --- Pull vertical ---
  if (mentionsPullVertical) return 'pull_vertical';

  // --- Pull horizontal ---
  if (isBack && mentionsRow) return 'pull_horizontal';
  if (mentionsRow) return 'pull_horizontal';

  // --- Hinge ---
  if (mentionsHinge) return 'hinge';

  // --- Squat ---
  if (mentionsSquat) return 'squat';
  if (isLeg && any(n, ['extension', 'extensión', 'curl femoral'])) {
    // aislamientos de pierna: clasificarlos como other (no son patrones limpios)
    return 'other';
  }

  // --- Fallback por grupo si no hay match por nombre ---
  if (isChest) return 'push_horizontal';
  if (isShoulder) return 'push_vertical';
  if (isBack) return 'pull_horizontal';

  return 'other';
}
