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

/// Share links backed by two callbacks (the hosted backend's RPCs). The
/// callbacks return the raw token; this class turns it into a URL.
class CallbackShareLinkService implements ShareLinkService {
  CallbackShareLinkService({
    required this.create,
    required this.revoke,
    required this.canRevoke,
  });

  final Future<String> Function() create;
  final Future<void> Function() revoke;

  @override
  final bool canRevoke;

  @override
  Future<String> createLink() async => shareUrlForToken(await create());

  @override
  Future<void> revokeLinks() => revoke();
}
