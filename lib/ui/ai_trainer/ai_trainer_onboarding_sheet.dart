import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/ai_trainer_service.dart';
import 'ai_trainer_avatars.dart';

/// Onboarding del entrenador IA. Se muestra la primera vez que el usuario
/// se activa como Premium (o desde Settings si quiere reconfigurar).
class AITrainerOnboardingSheet extends StatefulWidget {
  const AITrainerOnboardingSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AITrainerOnboardingSheet(),
    );
  }

  @override
  State<AITrainerOnboardingSheet> createState() => _AITrainerOnboardingSheetState();
}

class _AITrainerOnboardingSheetState extends State<AITrainerOnboardingSheet> {
  int _step = 0;
  String _avatarId = AITrainerAvatars.ids.first;
  final _nameController = TextEditingController(text: 'Coach');
  String _tone = 'motivador';
  String _focus = 'ambos';
  bool _saving = false;

  static const _tones = [
    ('motivador', 'Motivador'),
    ('directo', 'Directo'),
    ('relajado', 'Relajado'),
    ('exigente', 'Exigente'),
  ];

  static const _focuses = [
    ('entrenamiento', 'Entrenamiento'),
    ('nutricion', 'Nutricion'),
    ('ambos', 'Ambos'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    HapticFeedback.lightImpact();
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      await AITrainerService.instance.saveConfig(
        name: _nameController.text.trim().isEmpty
            ? 'Coach'
            : _nameController.text.trim(),
        avatarId: _avatarId,
        tone: _tone,
        focus: _focus,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _stepHeader(),
            const SizedBox(height: 16),
            _stepBody(),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : _back,
                  child: Text(
                    _step == 0 ? 'Cancelar' : 'Atras',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_step == 3 ? 'Guardar' : 'Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader() {
    final titles = [
      'Elige el avatar de tu coach',
      'Como se llama?',
      'Que tono prefieres?',
      'En que te quiere enfocar?',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso ${_step + 1} de 4',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          titles[_step],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _avatarPicker();
      case 1:
        return _namePicker();
      case 2:
        return _chipsPicker(
          options: _tones,
          selected: _tone,
          onSelect: (v) => setState(() => _tone = v),
        );
      case 3:
        return _chipsPicker(
          options: _focuses,
          selected: _focus,
          onSelect: (v) => setState(() => _focus = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _avatarPicker() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: AITrainerAvatars.ids.map((id) {
        final selected = _avatarId == id;
        return GestureDetector(
          onTap: () => setState(() => _avatarId = id),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.accentOrange : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: AITrainerAvatars.circle(id: id, size: 64),
          ),
        );
      }).toList(),
    );
  }

  Widget _namePicker() {
    return TextField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.words,
      maxLength: 20,
      decoration: InputDecoration(
        hintText: 'Coach',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _chipsPicker({
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o.$1 == selected;
        return ChoiceChip(
          label: Text(o.$2),
          selected: isSel,
          onSelected: (_) => onSelect(o.$1),
          backgroundColor: AppColors.darkSurfaceElevated,
          selectedColor: AppColors.accentOrange,
          labelStyle: TextStyle(
            color: isSel ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: isSel ? AppColors.accentOrange : AppColors.darkBorder,
          ),
        );
      }).toList(),
    );
  }
}
