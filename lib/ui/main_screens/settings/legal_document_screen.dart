import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../services/supabase_service.dart';

/// Visor generico para documentos legales (privacy / terms / community).
/// Renderiza markdown sencillo (encabezados con `#`/`##`, parrafos y bullets).
/// `flutter_markdown` no esta en pubspec; si se agrega en el futuro, este
/// fallback puede reemplazarse por un widget Markdown completo.
class LegalDocumentScreen extends StatefulWidget {
  final String slug; // 'privacy' | 'terms' | 'community'
  const LegalDocumentScreen({super.key, required this.slug});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String _content = '';
  bool _loading = true;
  String? _acceptedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _assetPath {
    switch (widget.slug) {
      case 'privacy':
        return 'assets/legal/privacy.md';
      case 'terms':
        return 'assets/legal/terms.md';
      case 'community':
      default:
        return 'assets/legal/community.md';
    }
  }

  String get _title {
    switch (widget.slug) {
      case 'privacy':
        return 'Politica de privacidad';
      case 'terms':
        return 'Terminos y condiciones';
      case 'community':
      default:
        return 'Reglas de comunidad';
    }
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(_assetPath);
      String? acceptedAt;
      try {
        final profile = await SupabaseService.instance.getRawMyProfile();
        dynamic raw;
        if (widget.slug == 'privacy') {
          raw = profile?['privacy_consent_at'];
        } else if (widget.slug == 'terms') {
          raw = profile?['terms_consent_at'];
        }
        if (raw is String && raw.isNotEmpty) {
          final dt = DateTime.tryParse(raw);
          if (dt != null) {
            acceptedAt = DateFormat.yMMMd().format(dt.toLocal());
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _content = text;
        _acceptedAt = acceptedAt;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _content = 'No se pudo cargar el documento.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsSurface,
      appBar: AppBar(
        backgroundColor: AppColors.settingsSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_title),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._renderMarkdown(_content),
                    if (_acceptedAt != null) ...[
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.settingsDivider),
                      const SizedBox(height: 12),
                      Text(
                        'Aceptado el $_acceptedAt',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _renderMarkdown(String md) {
    final lines = md.split('\n');
    final widgets = <Widget>[];
    final buffer = StringBuffer();

    void flushParagraph() {
      final text = buffer.toString().trim();
      buffer.clear();
      if (text.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          _stripInlineMd(text),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ));
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('# ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            line.substring(2).trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(
            line.substring(3).trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(
            line.substring(4).trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, right: 8),
                child: Icon(Icons.circle, size: 5, color: Colors.white54),
              ),
              Expanded(
                child: Text(
                  _stripInlineMd(line.substring(2).trim()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.isEmpty) {
        flushParagraph();
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(line);
      }
    }
    flushParagraph();
    return widgets;
  }

  String _stripInlineMd(String s) {
    return s
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'__(.+?)__'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
  }
}
