import 'package:flutter/material.dart';

/// Semantic status colors (lunas / sebagian / belum bayar / info). Always show
/// them with a text label — color alone must never carry the meaning.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.info,
    required this.onInfo,
  });

  /// Container colors with their readable "on" text colors.
  final Color success, onSuccess;
  final Color warning, onWarning;
  final Color danger, onDanger;
  final Color info, onInfo;

  static const light = StatusColors(
    success: Color(0xffd7efdc),
    onSuccess: Color(0xff0b3d1b),
    warning: Color(0xfffbe8c0),
    onWarning: Color(0xff4a3000),
    danger: Color(0xfffadad7),
    onDanger: Color(0xff5c0f0a),
    info: Color(0xffd6e4f7),
    onInfo: Color(0xff0f2f5c),
  );

  static const dark = StatusColors(
    success: Color(0xff1b4a2a),
    onSuccess: Color(0xffcdeed4),
    warning: Color(0xff5a3f08),
    onWarning: Color(0xfff8e3b5),
    danger: Color(0xff6b1f1a),
    onDanger: Color(0xfff9d6d2),
    info: Color(0xff1d3f6e),
    onInfo: Color(0xffd3e3f8),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? info,
    Color? onInfo,
  }) => StatusColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StatusColors(
      success: l(success, other.success),
      onSuccess: l(onSuccess, other.onSuccess),
      warning: l(warning, other.warning),
      onWarning: l(onWarning, other.onWarning),
      danger: l(danger, other.danger),
      onDanger: l(onDanger, other.onDanger),
      info: l(info, other.info),
      onInfo: l(onInfo, other.onInfo),
    );
  }
}
