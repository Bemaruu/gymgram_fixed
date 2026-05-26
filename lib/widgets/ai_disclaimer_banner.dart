import 'package:flutter/material.dart';

class AIDisclaimerBanner extends StatelessWidget {
  final EdgeInsets margin;
  const AIDisclaimerBanner({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 16, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sugerencias generadas por IA. No constituyen consejo médico ni nutricional profesional. Consulta a un especialista antes de cambios significativos.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
