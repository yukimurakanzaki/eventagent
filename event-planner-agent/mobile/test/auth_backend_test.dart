import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargakas_mobile/supabase_backend.dart';

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test('callback accepts only the app auth endpoint', () {
    expect(
      SupabaseBackend.isAuthCallback(
        Uri.parse('${SupabaseBackend.authRedirectUrl}?code=test'),
      ),
      isTrue,
    );
    expect(
      SupabaseBackend.isAuthCallback(
        Uri.parse('https://example.com/?code=test'),
      ),
      isFalse,
    );
    expect(
      SupabaseBackend.isAuthCallback(
        Uri.parse('io.wargakas.mobile://other/?code=test'),
      ),
      isFalse,
    );
    expect(
      SupabaseBackend.isAuthCallback(
        Uri.parse('io.wargakas.mobile://auth-callback/unrelated'),
      ),
      isFalse,
    );
  });

  test(
    'real SDK signup, resend and recovery preserve redirect and PKCE challenge',
    () async {
      final requests = <http.Request>[];
      final storage = MemoryPkceStorage();
      final client = SupabaseClient(
        'https://project.example.com',
        'public-test-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.pkce,
          pkceAsyncStorage: storage,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/signup')
                  ? {
                      'id': 'obfuscated-or-pending',
                      'aud': 'authenticated',
                      'app_metadata': {},
                      'user_metadata': {},
                      'created_at': '2026-09-05',
                      'identities': [],
                    }
                  : {},
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final backend = SupabaseBackend(client);
      final response = await backend.signUp(
        ' person@example.com ',
        ' pass word ',
      );
      expect(response.session, isNull);
      expect(response.user?.id, 'obfuscated-or-pending');
      await backend.resendSignupConfirmation(' person@example.com ');
      await backend.sendPasswordReset(' person@example.com ');
      expect(requests.map((request) => request.url.path), [
        '/auth/v1/signup',
        '/auth/v1/resend',
        '/auth/v1/recover',
      ]);
      final challenges = <String>[];
      for (final request in requests) {
        expect(
          request.url.queryParameters['redirect_to'],
          SupabaseBackend.authRedirectUrl,
        );
        final body = jsonDecode(request.body) as Map;
        expect(body['email'], 'person@example.com');
        expect(body['code_challenge_method'], 's256');
        expect(body['code_challenge'], isNotEmpty);
        challenges.add(body['code_challenge'] as String);
      }
      expect(challenges.toSet().length, 3);
      expect(
        (jsonDecode(requests.first.body) as Map)['password'],
        ' pass word ',
      );
      expect(storage.values.values.single, contains('passwordRecovery'));
    },
  );

  test(
    'real SDK retains machine-readable auth failure for UI mapping',
    () async {
      final client = SupabaseClient(
        'https://project.example.com',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'code': 'invalid_credentials',
              'msg': 'Invalid login credentials',
            }),
            400,
            headers: {
              'content-type': 'application/json',
              'x-supabase-api-version': '2024-01-01',
            },
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseBackend(client).signIn('person@example.com', 'wrong'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
    },
  );
}
