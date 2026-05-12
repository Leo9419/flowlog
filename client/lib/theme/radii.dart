import 'package:flutter/widgets.dart';

/// 圆角 token。
///
/// 提供原始数值与预构造的 `Radius` / `BorderRadius` 实例，
/// 调用方可按需选取，避免 `Radius.circular(10)` 散落各处。
class FlowRadii {
  const FlowRadii._();

  // —— 原始数值（dp）——
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;

  // —— 预构造 Radius ——
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);

  // —— 预构造 BorderRadius ——
  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
}
