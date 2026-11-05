import 'package:intl/intl.dart';

import 'l10n/l10n.dart';

const _idMonthShort = [
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

String intlLocale([String? languageCode]) =>
    switch (languageCode ?? L10n.code) {
      'zh' => 'zh_CN',
      'pt' => 'pt_BR',
      final code => code,
    };

/// Runs [format] with the active locale and falls back to English if the
/// date symbols for it are not loaded (e.g. in a bare unit test).
String _withLocale(String Function(String locale) format) {
  try {
    return format(intlLocale());
  } catch (_) {
    return format('en');
  }
}

/// Short numeric date in the user's convention: 12/09/2026, 9/12/2026, ...
String formatDate(DateTime date) {
  if (L10n.code == 'id') {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  return _withLocale((locale) => DateFormat.yMd(locale).format(date));
}

/// "12 Sep 2026": month names read faster than numbers for older users.
String formatDateLong(DateTime date) {
  if (L10n.code == 'id') {
    return '${date.day} ${_idMonthShort[date.month - 1]} ${date.year}';
  }
  return _withLocale((locale) => DateFormat.yMMMd(locale).format(date));
}

String formatDateRange(DateTime start, DateTime end) {
  if (L10n.code != 'id') {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return formatDateLong(start);
    }
    return '${formatDateLong(start)} – ${formatDateLong(end)}';
  }
  if (start.year != end.year) {
    return '${formatDateLong(start)} – ${formatDateLong(end)}';
  }
  if (start.month != end.month) {
    return '${start.day} ${_idMonthShort[start.month - 1]} – ${formatDateLong(end)}';
  }
  if (start.day == end.day) return formatDateLong(start);
  return '${start.day}–${end.day} ${_idMonthShort[end.month - 1]} ${end.year}';
}

String formatTime(DateTime date) {
  if (L10n.code == 'id') {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  return _withLocale((locale) => DateFormat.jm(locale).format(date));
}

String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${formatTime(date)}';

/// "Sep 2026" style month heading.
String formatMonthYear(DateTime date) {
  if (L10n.code == 'id') {
    const full = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${full[date.month - 1]} ${date.year}';
  }
  return _withLocale((locale) => DateFormat.yMMMM(locale).format(date));
}
