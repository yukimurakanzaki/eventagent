import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargakas_mobile/supabase_app.dart';

void main() {
  test('connectivity failures keep the check-internet advice', () {
    expect(
      loadErrorMessage(TimeoutException('slow')),
      contains('Periksa koneksi internet'),
    );
    expect(
      loadErrorMessage(const SocketException('offline')),
      contains('Periksa koneksi internet'),
    );
  });

  test('database errors show their code and message', () {
    final message = loadErrorMessage(
      const PostgrestException(
        message: 'column events.archived_at does not exist',
        code: '42703',
      ),
    );
    expect(
      message,
      contains('42703: column events.archived_at does not exist'),
    );
    expect(message, isNot(contains('Periksa koneksi internet')));
  });

  test('unknown errors are shown and long ones are shortened', () {
    expect(loadErrorMessage(StateError('boom')), contains('boom'));
    expect(loadErrorMessage(StateError('x' * 500)).length, lessThan(260));
  });
}
