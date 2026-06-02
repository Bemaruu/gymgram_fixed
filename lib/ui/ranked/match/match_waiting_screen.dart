import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';
import '../../../widgets/tier_emblem_badge.dart';
import 'match_screen.dart';

/// Pantalla de espera tras enviar un desafio 1v1.
/// Escucha realtime sobre match_challenges y navega a la partida cuando se
/// acepta. Si se rechaza, vuelve atras con un snackbar.
class MatchWaitingScreen extends StatefulWidget {
  final String challengeId;
  final MatchPlayer rival;
  const MatchWaitingScreen({
    super.key,
    required this.challengeId,
    required this.rival,
  });

  @override
  State<MatchWaitingScreen> createState() => _MatchWaitingScreenState();
}

class _MatchWaitingScreenState extends State<MatchWaitingScreen> {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
    // Fallback: poll cada 4s por si Realtime falla.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
    // Check inicial inmediato.
    _checkStatus();
  }

  void _subscribe() {
    _channel = _client.channel('challenge:${widget.challengeId}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'match_challenges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.challengeId,
          ),
          callback: (payload) => _handleRow(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _checkStatus() async {
    if (_resolved) return;
    try {
      final row = await _client
          .from('match_challenges')
          .select('status, match_id')
          .eq('id', widget.challengeId)
          .maybeSingle();
      if (row != null) _handleRow(Map<String, dynamic>.from(row));
    } catch (_) {}
  }

  void _handleRow(Map<String, dynamic> row) {
    if (_resolved || !mounted) return;
    final status = row['status'] as String?;
    final matchId = row['match_id'] as String?;
    if (status == 'accepted' && matchId != null) {
      _resolved = true;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => MatchScreen(matchId: matchId),
      ));
    } else if (status == 'rejected') {
      _resolved = true;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurfaceElevated,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '@${widget.rival.username} rechazó tu desafío.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } else if (status == 'cancelled') {
      _resolved = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancel() async {
    if (_resolved) return;
    _resolved = true;
    try {
      await _client.rpc('cancel_match_challenge',
          params: {'p_challenge_id': widget.challengeId});
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _cancel,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  const Spacer(),
                ],
              ),
              const Spacer(),
              const Text(
                'DESAFÍO ENVIADO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.accentOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentOrange.withValues(alpha: 0.6),
                      ),
                    ),
                    TierEmblemBadge(tier: widget.rival.tier, size: 84),
                    Positioned(
                      bottom: 12,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.darkSurfaceElevated,
                        backgroundImage: widget.rival.avatarUrl != null
                            ? NetworkImage(widget.rival.avatarUrl!)
                            : null,
                        child: widget.rival.avatarUrl == null
                            ? const Icon(Icons.person,
                                color: Colors.white54, size: 22)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Esperando a @${widget.rival.username}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuando acepte, te llevaremos al duelo automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _cancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancelar desafío',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
