import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/badge_model.dart';

/// Tarjeta compartible de una medalla, diseñada para verse bien al postearse
/// en redes (stories, WhatsApp, etc.). Lo que se ve = lo que se comparte.
///
/// Si [pioneroNumber] viene y la medalla es la de la beta, muestra
/// "Pionero #N".
class MedalShareCard extends StatelessWidget {
  final BadgeModel badge;
  final int? pioneroNumber;

  const MedalShareCard({
    super.key,
    required this.badge,
    this.pioneroNumber,
  });

  static const _gold = Color(0xFFFFC53D);

  @override
  Widget build(BuildContext context) {
    final accent =
        badge.id == 'beta_exclusiva' ? _gold : badge.rank.color;
    final showPionero =
        badge.id == 'beta_exclusiva' && pioneroNumber != null;

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12203A), Color(0xFF0A1424)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'GymGram',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Image.asset(
              badge.imagePath,
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(badge.rank.icon, size: 120, color: accent),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              badge.id == 'beta_exclusiva'
                  ? '👑 EXCLUSIVA DE LA BETA'
                  : badge.rank.label.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            badge.medalName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showPionero) ...[
            const SizedBox(height: 6),
            Text(
              'Pionero #${pioneroNumber.toString().padLeft(3, '0')}',
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 12),
          const Text(
            'gymgram.fit',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Captura el widget envuelto por [boundaryKey] (un RepaintBoundary) como PNG
/// y abre el menú nativo de compartir. Devuelve false si algo falla.
Future<bool> shareMedalImage({
  required GlobalKey boundaryKey,
  required String text,
  String fileName = 'gymgram_medalla.png',
}) async {
  try {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return false;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes.buffer.asUint8List());

    await Share.shareXFiles([XFile(file.path)], text: text);
    return true;
  } catch (_) {
    return false;
  }
}
