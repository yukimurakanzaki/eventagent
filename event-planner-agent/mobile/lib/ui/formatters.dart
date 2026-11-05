part of '../main.dart';

String roleLabel(String? role) {
  switch (role) {
    case 'treasurer':
      return 'Bendahara';
    case 'chairperson':
      return 'Ketua acara';
    default:
      return 'Anggota acara';
  }
}

String refundPolicyLabel(RefundPolicy policy) {
  switch (policy) {
    case RefundPolicy.undecided:
      return 'Belum diputuskan';
    case RefundPolicy.none:
      return 'Tidak ada refund';
    case RefundPolicy.partial:
      return 'Refund sebagian';
    case RefundPolicy.full:
      return 'Refund penuh';
  }
}

/// Formats an amount in the open event's currency.
