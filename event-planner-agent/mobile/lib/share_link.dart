import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the read-only participant view is hosted (the web build of this
/// app). Override with --dart-define=WARGAKAS_SHARE_BASE_URL=...
const shareBaseUrl = String.fromEnvironment(
  'WARGAKAS_SHARE_BASE_URL',
  defaultValue: 'https://yukimurakanzaki.github.io/eventagent/',
);

String shareUrlForToken(String token) {
  final base = Uri.parse(shareBaseUrl);
  return base
      .replace(queryParameters: {...base.queryParameters, 'share': token})
      .toString();
}

/// Creates and revokes the participant read-only link for the open event.
abstract interface class ShareLinkService {
  /// The current link, creating one if none is active.
  Future<String> createLink();

  /// Invalidates every link; only the treasurer may do this.
  Future<void> revokeLinks();

  bool get canRevoke;
}

class SupabaseShareLinkService implements ShareLinkService {
  SupabaseShareLinkService({
    required this.client,
    required this.eventId,
    required this.role,
  });

  final SupabaseClient client;
  final String eventId;
  final String role;

  @override
  bool get canRevoke => role == 'treasurer';

  @override
  Future<String> createLink() async {
    final token = await client.rpc(
      'create_share_link',
      params: {'p_event_id': eventId},
    );
    return shareUrlForToken(token as String);
  }

  @override
  Future<void> revokeLinks() async {
    await client.rpc('revoke_share_links', params: {'p_event_id': eventId});
  }
}
