import 'package:flutter/material.dart';

enum BadgeRank { bronce, plata, oro, diamante, especial, evento, mineral }

extension BadgeRankExt on BadgeRank {
  String get label {
    switch (this) {
      case BadgeRank.bronce:
        return 'Bronce';
      case BadgeRank.plata:
        return 'Plata';
      case BadgeRank.oro:
        return 'Oro';
      case BadgeRank.diamante:
        return 'Diamante';
      case BadgeRank.especial:
        return 'Especial';
      case BadgeRank.evento:
        return 'Evento';
      case BadgeRank.mineral:
        return 'Mineral';
    }
  }

  Color get color {
    switch (this) {
      case BadgeRank.bronce:
        return const Color(0xFFCD7F32);
      case BadgeRank.plata:
        return const Color(0xFFBDBDBD);
      case BadgeRank.oro:
        return const Color(0xFFFFD700);
      case BadgeRank.diamante:
        return const Color(0xFF40C4FF);
      case BadgeRank.especial:
        return const Color(0xFFAA00FF);
      case BadgeRank.evento:
        return const Color(0xFFFF6D00);
      case BadgeRank.mineral:
        return const Color(0xFF00E5FF);
    }
  }

  Color get darkColor {
    switch (this) {
      case BadgeRank.bronce:
        return const Color(0xFF6B3F0A);
      case BadgeRank.plata:
        return const Color(0xFF616161);
      case BadgeRank.oro:
        return const Color(0xFF8B6914);
      case BadgeRank.diamante:
        return const Color(0xFF0277BD);
      case BadgeRank.especial:
        return const Color(0xFF4A0080);
      case BadgeRank.evento:
        return const Color(0xFFBF360C);
      case BadgeRank.mineral:
        return const Color(0xFF006064);
    }
  }

  IconData get icon {
    switch (this) {
      case BadgeRank.bronce:
        return Icons.directions_run;
      case BadgeRank.plata:
        return Icons.fitness_center;
      case BadgeRank.oro:
        return Icons.emoji_events;
      case BadgeRank.diamante:
        return Icons.diamond;
      case BadgeRank.especial:
        return Icons.auto_awesome;
      case BadgeRank.evento:
        return Icons.flag;
      case BadgeRank.mineral:
        return Icons.hexagon;
    }
  }
}

class BadgeModel {
  final String id;
  final String title;
  final String medalName;
  final String description;
  final String condition;
  final BadgeRank rank;
  final int difficulty;
  final String imagePath;
  final bool isLimited;
  final bool isGlobalEvent;

  /// Si true, la medalla se obtiene subiendo una foto que la IA verifica
  /// (edge function verify-medal-photo). El criterio vive en el servidor.
  final bool requiresPhotoProof;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.medalName,
    required this.description,
    required this.condition,
    required this.rank,
    this.difficulty = 5,
    required this.imagePath,
    this.isLimited = false,
    this.isGlobalEvent = false,
    this.requiresPhotoProof = false,
  });
}

class UserBadgeModel {
  final String badgeId;
  final DateTime earnedAt;
  final double progress;
  final bool isFeatured;
  final int? featuredOrder;

  const UserBadgeModel({
    required this.badgeId,
    required this.earnedAt,
    this.progress = 1.0,
    this.isFeatured = false,
    this.featuredOrder,
  });

  factory UserBadgeModel.fromMap(Map<String, dynamic> map) {
    return UserBadgeModel(
      badgeId: map['badge_id'] as String,
      earnedAt: DateTime.parse(map['earned_at'] as String),
      progress: (map['progress'] as num?)?.toDouble() ?? 1.0,
      isFeatured: map['is_featured'] as bool? ?? false,
      featuredOrder: map['featured_order'] as int?,
    );
  }
}
