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

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "12 Sep 2026": month names read faster than 12/09/2026 for older users.
String formatDateLong(DateTime date) =>
    '${date.day} ${_monthShort[date.month - 1]} ${date.year}';

String formatDateRange(DateTime start, DateTime end) {
  if (start.year != end.year) {
    return '${formatDateLong(start)} – ${formatDateLong(end)}';
  }
  if (start.month != end.month) {
    return '${start.day} ${_monthShort[start.month - 1]} – ${formatDateLong(end)}';
  }
  if (start.day == end.day) return formatDateLong(start);
  return '${start.day}–${end.day} ${_monthShort[end.month - 1]} ${end.year}';
}

String formatDateTime(DateTime date) {
  return '${formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String rupiah(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  return 'Rp $sign${groups.join('.')}';
}
