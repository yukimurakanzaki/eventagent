import 'package:flutter/material.dart';

import 'cashbook_calculations.dart';
import 'status_colors.dart';

/// Pay state as icon + label + tone. The label always carries the meaning, so
/// color is only reinforcement (and survives grayscale / color blindness).
class PayStateChip extends StatelessWidget {
  const PayStateChip(this.state, {this.label, super.key});

  final PayState state;
  final String? label;

  static String textFor(PayState state) => switch (state) {
    PayState.paid => 'Lunas',
    PayState.partial => 'Sebagian',
    PayState.unpaid => 'Belum bayar',
  };

  static IconData iconFor(PayState state) => switch (state) {
    PayState.paid => Icons.check_circle_outline,
    PayState.partial => Icons.timelapse,
    PayState.unpaid => Icons.radio_button_unchecked,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StatusColors>()!;
    final (tone, onTone) = switch (state) {
      PayState.paid => (colors.success, colors.onSuccess),
      PayState.partial => (colors.warning, colors.onWarning),
      PayState.unpaid => (colors.danger, colors.onDanger),
    };
    return StatusPill(
      label: label ?? textFor(state),
      icon: iconFor(state),
      tone: tone,
      onTone: onTone,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTone,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color tone, onTone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 18, color: onTone)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: onTone, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
