import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsageDashboardScreen extends StatefulWidget {
  const UsageDashboardScreen({super.key});

  @override
  State<UsageDashboardScreen> createState() => _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends State<UsageDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.rpc('get_usage_stats');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(res as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('Forbidden')
            ? 'No tienes acceso a este panel.'
            : 'Error: $e';
        _loading = false;
      });
    }
  }

  String _formatBytes(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _colorFor(double pct) {
    if (pct >= 80) return const Color(0xFFFF4D4D);
    if (pct >= 60) return const Color(0xFFFFB400);
    return const Color(0xFF00BFFF);
  }

  Widget _meter({
    required String label,
    required double pct,
    required String usedLabel,
    required String limitLabel,
  }) {
    final clamped = pct.clamp(0.0, 100.0);
    final color = _colorFor(pct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)} %',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFF1A1A1A),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$usedLabel / $limitLabel',
            style: const TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Uso del backend',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final dbPct = (d['db_pct'] as num).toDouble();
    final stPct = (d['storage_pct'] as num).toDouble();
    final dbBytes = (d['db_bytes'] as num);
    final dbLimit = (d['db_limit_bytes'] as num);
    final stBytes = (d['storage_bytes'] as num);
    final stLimit = (d['storage_limit_bytes'] as num);

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF00BFFF),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF00BFFF), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Free plan: 500 MB DB, 1 GB storage, 5 GB egress/mes.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Capacidad',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          _meter(
            label: 'Base de datos',
            pct: dbPct,
            usedLabel: _formatBytes(dbBytes),
            limitLabel: _formatBytes(dbLimit),
          ),
          _meter(
            label: 'Storage (imágenes/videos)',
            pct: stPct,
            usedLabel: _formatBytes(stBytes),
            limitLabel: _formatBytes(stLimit),
          ),
          const SizedBox(height: 18),
          const Text(
            'Actividad',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _stat('Usuarios', '${d['profiles']}'),
                _stat('Posts', '${d['posts']}'),
                _stat('Chats', '${d['chats']}'),
                _stat('Mensajes totales', '${d['messages']}'),
                _stat('Mensajes últimos 30 días', '${d['messages_30d']}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Egress (transferencia de salida) no se mide aquí — revisa el dashboard de Supabase si te acercas al 80% de DB o Storage.',
            style: const TextStyle(color: Colors.white38, fontSize: 11.5, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Text(
            'Generado: ${(d['generated_at'] as String?)?.substring(0, 19) ?? ''}',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
