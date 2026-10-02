import 'package:supabase_flutter/supabase_flutter.dart';

import 'cashbook_models.dart';
import 'cashbook_controller.dart';
import 'cashbook_sync.dart';
import 'event_directory.dart';

class SupabaseBackend {
  SupabaseBackend(this.client);

  static const appMode = String.fromEnvironment(
    'WARGAKAS_APP_MODE',
    defaultValue: 'hosted',
  );
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const authRedirectUrl = 'io.wargakas.mobile://auth-callback/';

  static bool isAuthCallback(Uri uri) =>
      uri.scheme == 'io.wargakas.mobile' &&
      uri.host == 'auth-callback' &&
      (uri.path.isEmpty || uri.path == '/');

  final SupabaseClient client;

  static bool get isDemoMode => appMode == 'demo';

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static String? get configurationError {
    if (isDemoMode || isConfigured) return null;
    return 'Build ini belum terhubung ke Supabase. Gunakan build hosted dengan SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.';
  }

  static Future<SupabaseBackend?> initializeFromEnvironment() async {
    if (!isConfigured) return null;
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUriPredicate: isAuthCallback,
      ),
    );
    return SupabaseBackend(Supabase.instance.client);
  }

  User? get user => client.auth.currentUser;

  Session? get currentSession => client.auth.currentSession;

  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: authRedirectUrl,
    );
  }

  Future<void> resendSignupConfirmation(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: authRedirectUrl,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: authRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() => client.auth.signOut();

  Future<OpenedCashbook> loadCashbook({String? preferredEventId}) async {
    final userId = user?.id;
    if (userId == null) throw AuthSessionMissingException();
    final adapter = await openCashbook(
      CashbookSnapshot.blank(),
      preferredEventId: preferredEventId,
    );
    if (user?.id != userId) throw AuthSessionMissingException();
    final controller = await CashbookController.bootstrap(
      syncAdapter: adapter,
      storageNamespace: '$userId-${adapter.workspaceId}-${adapter.eventId}',
    );
    if (user?.id != userId) {
      controller.dispose();
      throw AuthSessionMissingException();
    }
    return OpenedCashbook(
      controller,
      adapter.workspaceId,
      adapter.role,
      adapter.eventId,
    );
  }

  Future<SupabaseCashbookSyncAdapter> openCashbook(
    CashbookSnapshot seed, {
    String? preferredEventId,
  }) async {
    final userId = user?.id;
    if (userId == null) throw AuthSessionMissingException();
    final membership = await client
        .from('workspace_members')
        .select('workspace_id, role')
        .order('created_at')
        .limit(1)
        .maybeSingle();

    if (user?.id != userId) throw AuthSessionMissingException();

    if (membership == null) {
      final created = await client.rpc(
        'create_workspace_with_event',
        params: {'p_workspace_name': 'Wargakas', 'p_snapshot': seed.toJson()},
      );
      final data = Map<String, dynamic>.from(created as Map);
      return SupabaseCashbookSyncAdapter(
        client: client,
        workspaceId: data['workspace_id'] as String,
        eventId: data['event_id'] as String,
        role: 'treasurer',
      );
    }

    final workspaceId = membership['workspace_id'] as String;
    final events = await listEvents(workspaceId);
    if (events.isEmpty) {
      throw StateError(
        'Akun belum memiliki acara. Buat acara pertama melalui dashboard Supabase.',
      );
    }
    final event = events.firstWhere(
      (item) => item.id == preferredEventId,
      orElse: () => events.firstWhere(
        (item) => !item.archived,
        orElse: () => events.first,
      ),
    );
    return SupabaseCashbookSyncAdapter(
      client: client,
      workspaceId: workspaceId,
      eventId: event.id,
      role: membership['role'] as String? ?? 'chairperson',
    );
  }

  /// Oldest first, so the fallback event matches the pre-archive behaviour.
  Future<List<EventSummary>> listEvents(String workspaceId) async {
    final rows = await client
        .from('events')
        .select('id, name, start_date, end_date, archived_at')
        .eq('workspace_id', workspaceId)
        .order('created_at');
    return [
      for (final row in rows)
        EventSummary(
          id: row['id'] as String,
          name: row['name'] as String,
          startDate: DateTime.parse(row['start_date'] as String),
          endDate: DateTime.parse(row['end_date'] as String),
          archived: row['archived_at'] != null,
        ),
    ];
  }

  Future<String> createEvent(String workspaceId, NewEventDraft draft) async {
    final created = await client.rpc(
      'create_event',
      params: {
        'p_workspace_id': workspaceId,
        'p_snapshot': draft.toSnapshot().toJson(),
      },
    );
    return (created as Map)['event_id'] as String;
  }

  Future<void> setEventArchived(String eventId, bool archived) async {
    await client.rpc(
      'set_event_archived',
      params: {'p_event_id': eventId, 'p_archived': archived},
    );
  }

  Future<void> inviteChairperson({
    required String workspaceId,
    required String email,
  }) async {
    await client.rpc(
      'invite_workspace_member',
      params: {
        'p_workspace_id': workspaceId,
        'p_email': email.trim(),
        'p_role': 'chairperson',
      },
    );
  }
}

class OpenedCashbook {
  const OpenedCashbook(
    this.controller,
    this.workspaceId,
    this.role,
    this.eventId,
  );
  final CashbookController controller;
  final String workspaceId;
  final String role;
  final String eventId;
}

class SupabaseCashbookSyncAdapter implements CashbookSyncAdapter {
  const SupabaseCashbookSyncAdapter({
    required this.client,
    required this.workspaceId,
    required this.eventId,
    required this.role,
  });

  final SupabaseClient client;
  final String workspaceId;
  final String eventId;
  final String role;

  @override
  Future<CashbookSnapshot?> load() async {
    final row = await client
        .from('cashbook_states')
        .select('snapshot, version')
        .eq('event_id', eventId)
        .maybeSingle();
    if (row == null) return null;
    final snapshot = CashbookSnapshot.fromJson(
      Map<String, dynamic>.from(row['snapshot'] as Map),
    );
    return snapshot.copyWith(syncVersion: (row['version'] as num).toInt());
  }

  @override
  Future<SyncResult> push({
    required CashbookSnapshot snapshot,
    required SyncOperation operation,
  }) async {
    final alignedSnapshot = snapshot.copyWith(
      event: snapshot.event.copyWith(id: eventId),
    );
    final response = await client.rpc(
      'sync_cashbook_state',
      params: {
        'p_event_id': eventId,
        'p_snapshot': alignedSnapshot.toJson(),
        'p_base_version': snapshot.syncVersion,
        'p_operation_id': operation.id,
        'p_entity': operation.entity,
        'p_entity_id': operation.entityId,
        'p_action': operation.action,
      },
    );
    final data = Map<String, dynamic>.from(response as Map);
    final version = (data['version'] as num).toInt();
    if (data['status'] == 'conflict') {
      return SyncResult.conflict(
        version: version,
        remoteUpdatedBy: data['updated_by'] as String?,
        remoteUpdatedAt: data['updated_at'] == null
            ? null
            : DateTime.parse(data['updated_at'] as String),
        remoteSnapshot: CashbookSnapshot.fromJson(
          Map<String, dynamic>.from(data['snapshot'] as Map),
        ).copyWith(syncVersion: version),
      );
    }
    return SyncResult.synced(version: version);
  }
}
