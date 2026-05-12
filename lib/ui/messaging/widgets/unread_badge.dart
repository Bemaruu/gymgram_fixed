import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double size;
  const UnreadBadge({super.key, required this.count, this.size = 18});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFFF),
        borderRadius: BorderRadius.circular(size),
        boxShadow: const [
          BoxShadow(color: Color(0x4D00BFFF), blurRadius: 6),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }
}
