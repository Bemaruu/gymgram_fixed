import 'package:flutter/animation.dart';

class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration xslow = Duration(milliseconds: 700);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve bouncy = Curves.easeOutBack;
  static const Curve elastic = Curves.elasticOut;
  static const Curve standard = Curves.easeInOutCubic;
}
