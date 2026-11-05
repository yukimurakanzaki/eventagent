part of '../main.dart';

String roleLabel(String? role) {
  switch (role) {
    case 'treasurer':
      return tr('Bendahara');
    case 'chairperson':
      return tr('Ketua acara');
    default:
      return tr('Anggota acara');
  }
}

String refundPolicyLabel(RefundPolicy policy) {
  switch (policy) {
    case RefundPolicy.undecided:
      return tr('Belum diputuskan');
    case RefundPolicy.none:
      return tr('Tidak ada refund');
    case RefundPolicy.partial:
      return tr('Refund sebagian');
    case RefundPolicy.full:
      return tr('Refund penuh');
  }
}

/// Formats an amount in the open event's currency.
