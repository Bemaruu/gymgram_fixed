import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Panel de moderación: lista los reportes de usuarios/mensajes y permite
/// marcarlos como revisados o descartados. Gateado por app.admin_uid en las
/// RPCs admin_list_reports / admin_resolve_report (server-side).
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  static const _accent = Color(0xFF00BFFF);

  final _statuses = const ['pending', 'reviewed', 'dismissed', 'all'];
  final _statusLabels = const {
    'pending': 'Pendientes',
    'reviewed': 'Revisados',
    'dismissed': 'Descartados',
    'all': 'Todos',
  };

  String _status = 'pending';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

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
      final res = await Supabase.instance.client.rpc(
        'admin_list_reports',
        params: {'p_status': _status, 'p_limit': 200},
      );
      if (!mounted) return;
      setState(() {
        _reports = (res as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
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

  Future<void> _resolve(String reportId, String action) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_resolve_report',
        params: {'p_report_id': reportId, 'p_action': action},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'reviewed' ? 'Marcado como revisado' : 'Descartado'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el reporte')),
      );
    }
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
          'Moderación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _accent))
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
                    : _reports.isEmpty
                        ? const Center(
                            child: Text(
                              'Sin reportes en esta categoría.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: _accent,
                            backgroundColor: const Color(0xFF1A1A1A),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: _reports.length,
                              itemBuilder: (_, i) => _buildReportCard(_reports[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _statuses.map((s) {
          final selected = s == _status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_statusLabels[s]!),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              selectedColor: _accent,
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) {
                if (s != _status) {
                  setState(() => _status = s);
                  _load();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    final status = r['status'] as String? ?? 'pending';
    final reason = r['reason'] as String? ?? '';
    final target = r['target_username'] as String? ?? '—';
    final reporter = r['reporter_username'] as String? ?? '—';
    final messageId = r['target_message_id'] as String?;
    final messageText = r['message_text'] as String?;
    final messageDeleted = r['message_deleted'] == true;
    final createdAt = (r['created_at'] as String?)?.replaceFirst('T', ' ').split('.').first ?? '';
    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                messageId != null ? Icons.sms_failed_outlined : Icons.person_off_outlined,
                size: 16,
                color: const Color(0xFFFF4D4D),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reportado: @$target',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 6),
          Text('Por: @$reporter', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Text(reason, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3)),
          if (messageId != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Text(
                messageDeleted
                    ? '(mensaje eliminado)'
                    : (messageText == null || messageText.isEmpty
                        ? '(sin contenido)'
                        : '"$messageText"'),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: messageDeleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(createdAt, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolve(r['id'] as String, 'dismissed'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolve(r['id'] as String, 'reviewed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Revisado'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = switch (status) {
      'pending' => const Color(0xFFFFB400),
      'reviewed' => const Color(0xFF00BFFF),
      _ => Colors.white38,
    };
    final label = _statusLabels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
