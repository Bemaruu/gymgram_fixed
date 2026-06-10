import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

enum MuscleGroup {
  chest,
  back,
  quad,
  hamstring,
  glute,
  shoulder,
  biceps,
  triceps,
  forearm,
  core,
  cardio,
  fullBody,
  other,
}

class MuscleIconMap {
  static const Map<MuscleGroup, IconData> iconByGroup = {
    MuscleGroup.chest: PhosphorIconsRegular.personSimpleTaiChi,
    MuscleGroup.back: PhosphorIconsRegular.personArmsSpread,
    MuscleGroup.quad: PhosphorIconsRegular.personSimpleWalk,
    MuscleGroup.hamstring: PhosphorIconsRegular.personSimpleRun,
    MuscleGroup.glute: PhosphorIconsRegular.barbell,
    MuscleGroup.shoulder: PhosphorIconsRegular.personSimple,
    MuscleGroup.biceps: PhosphorIconsRegular.barbell,
    MuscleGroup.triceps: PhosphorIconsRegular.barbell,
    MuscleGroup.forearm: PhosphorIconsRegular.handFist,
    MuscleGroup.core: PhosphorIconsRegular.personSimpleTaiChi,
    MuscleGroup.cardio: PhosphorIconsRegular.heartbeat,
    MuscleGroup.fullBody: PhosphorIconsRegular.personSimpleHike,
  };

  /// Heuristica por nombre de ejercicio o grupo (espanol).
  static MuscleGroup categorize(String name) {
    final n = name.toLowerCase().trim();
    bool any(List<String> kws) => kws.any((k) => n.contains(k));

    if (any([
      'pecho',
      'press de banca',
      'pectoral',
      'aperturas',
      'fondos en paralelas',
      'push',
    ])) {
      return MuscleGroup.chest;
    }
    if (any([
      'espalda',
      'dominada',
      'remo',
      'jalon',
      'jalón',
      'lat ',
      'dorsal',
      'pulldown',
    ])) {
      return MuscleGroup.back;
    }
    if (any([
      'cuadriceps',
      'cuádriceps',
      'sentadilla',
      'squat',
      'extension de pierna',
      'extensión de pierna',
      'leg press',
      'prensa',
    ])) {
      return MuscleGroup.quad;
    }
    if (any([
      'femoral',
      'isquio',
      'curl de pierna',
      'peso muerto rumano',
      'rdl',
      'hamstring',
    ])) {
      return MuscleGroup.hamstring;
    }
    if (any([
      'gluteo',
      'glúteo',
      'hip thrust',
      'patada',
      'kickback',
    ])) {
      return MuscleGroup.glute;
    }
    if (any([
      'hombro',
      'press militar',
      'overhead',
      'elevacion lateral',
      'elevación lateral',
      'pajaro',
      'pájaro',
      'deltoide',
    ])) {
      return MuscleGroup.shoulder;
    }
    if (any([
      'biceps',
      'bíceps',
      'curl con barra',
      'curl con mancuerna',
      'martillo',
      'predicador',
    ])) {
      return MuscleGroup.biceps;
    }
    if (any([
      'triceps',
      'tríceps',
      'extension de codo',
      'extensión de codo',
      'press frances',
      'press francés',
      'rompecraneos',
      'rompecráneos',
      'push-down',
      'pushdown',
    ])) {
      return MuscleGroup.triceps;
    }
    if (any([
      'antebrazo',
      'muneca',
      'muñeca',
      'forearm',
      'agarre',
      'grip',
    ])) {
      return MuscleGroup.forearm;
    }
    if (any([
      'core',
      'abdomen',
      'abdominal',
      'plancha',
      'crunch',
      'oblicuo',
    ])) {
      return MuscleGroup.core;
    }
    if (any([
      'cardio',
      'correr',
      'running',
      'bicicleta',
      'cinta',
      'eliptica',
      'elíptica',
      'rope',
      'cuerda',
      'hiit',
      'remo concept',
    ])) {
      return MuscleGroup.cardio;
    }
    if (any([
      'cuerpo completo',
      'full body',
      'fullbody',
      'circuito',
      'metcon',
    ])) {
      return MuscleGroup.fullBody;
    }

    return MuscleGroup.other;
  }

  static IconData? iconFor(String name) {
    final g = categorize(name);
    return iconByGroup[g];
  }
}
