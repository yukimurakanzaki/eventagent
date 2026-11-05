import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cashbook_models.dart';
import 'cashbook_controller.dart';
import 'cashbook_sync.dart';
import 'event_directory.dart';
import 'l10n/l10n.dart';

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
    return tr(
      'Build ini belum terhubung ke Supabase. Gunakan build hosted dengan SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.',
    );
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
      receiptUploader: uploadReceipt,
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
    // RLS shows every member of the user's workspaces, so filter to the
    // signed-in user or another member's role could be picked up.
    final memberships = await client
        .from('workspace_members')
        .select('workspace_id, role')
        .eq('user_id', userId)
        .order('created_at');

    if (user?.id != userId) throw AuthSessionMissingException();

    if (memberships.isEmpty) {
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

    final roles = <String, String>{
      for (final row in memberships)
        row['workspace_id'] as String: row['role'] as String? ?? 'chairperson',
    };
    final events = await listAllEvents(workspaceIds: roles.keys.toList());
    if (events.isEmpty) {
      throw StateError(
        tr(
          'Akun belum memiliki acara. Buat acara pertama melalui dashboard Supabase.',
        ),
      );
    }
    // A person can belong to several groups (their own and ones they were
    // invited to); without a saved choice open the most recently active.
    final byActivity = [...events]
      ..sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
    final event = events.firstWhere(
      (item) => item.id == preferredEventId,
      orElse: () => byActivity.firstWhere(
        (item) => !item.archived,
        orElse: () => byActivity.first,
      ),
    );
    return SupabaseCashbookSyncAdapter(
      client: client,
      workspaceId: event.workspaceId,
      eventId: event.id,
      role: roles[event.workspaceId] ?? 'chairperson',
    );
  }

  /// Every event in every workspace the user belongs to, oldest first.
  Future<List<EventSummary>> listAllEvents({List<String>? workspaceIds}) async {
    final userId = user?.id;
    if (userId == null) throw AuthSessionMissingException();
    final ids =
        workspaceIds ??
        [
          for (final row
              in await client
                  .from('workspace_members')
                  .select('workspace_id')
                  .eq('user_id', userId))
            row['workspace_id'] as String,
        ];
    if (ids.isEmpty) return const [];
    final rows = await client
        .from('events')
        .select(
          'id, workspace_id, name, start_date, end_date, archived_at, updated_at',
        )
        .inFilter('workspace_id', ids)
        .order('created_at');
    return [for (final row in rows) _eventSummary(row)];
  }

  EventSummary _eventSummary(Map<String, dynamic> row) => EventSummary(
    id: row['id'] as String,
    name: row['name'] as String,
    startDate: DateTime.parse(row['start_date'] as String),
    endDate: DateTime.parse(row['end_date'] as String),
    archived: row['archived_at'] != null,
    workspaceId: row['workspace_id'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(row['updated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Oldest first, so the fallback event matches the pre-archive behaviour.
  Future<List<EventSummary>> listEvents(String workspaceId) async {
    final rows = await client
        .from('events')
        .select(
          'id, workspace_id, name, start_date, end_date, archived_at, updated_at',
        )
        .eq('workspace_id', workspaceId)
        .order('created_at');
    return [for (final row in rows) _eventSummary(row)];
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

  Future<void> inviteMember({
    required String workspaceId,
    required String email,
    required String role,
  }) async {
    await client.rpc(
      'invite_workspace_member',
      params: {
        'p_workspace_id': workspaceId,
        'p_email': email.trim(),
        'p_role': role,
      },
    );
  }

  /// Permanently deletes the signed-in account (store requirement). The
  /// server hands the treasurer role to another member or removes a
  /// workspace nobody else can see.
  Future<void> deleteAccount() async {
    final userId = user?.id;
    // Receipt photos of groups that disappear with this account. Storage
    // files cannot be removed from SQL, so the app removes them first.
    try {
      final ids = await client.rpc('my_sole_workspace_event_ids');
      for (final eventId in (ids as List? ?? const []).cast<String>()) {
        final files = await client.storage.from('receipts').list(path: eventId);
        if (files.isEmpty) continue;
        await client.storage.from('receipts').remove([
          for (final file in files) '$eventId/${file.name}',
        ]);
      }
    } catch (_) {
      // Best effort; the runbook's orphan clean-up catches leftovers.
    }
    await client.rpc('delete_my_account');
    await _wipeLocalData(userId);
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // The user no longer exists server-side; local sign-out is enough.
    }
  }

  /// Removes this account's cached cashbooks, event choice and receipt
  /// photos from the phone after the account is deleted.
  Future<void> _wipeLocalData(String? userId) async {
    if (userId == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys().toList()) {
        if (key.contains(userId)) await preferences.remove(key);
      }
    } catch (_) {}
    if (kIsWeb) return;
    try {
      final receipts = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/receipts',
      );
      if (await receipts.exists()) await receipts.delete(recursive: true);
    } catch (_) {}
  }

  /// Uploads a receipt photo to `receipts/<eventId>/<transactionId>.<ext>`.
  Future<String?> uploadReceipt(
    String eventId,
    String transactionId,
    String localPath,
  ) async {
    final file = File(localPath);
    if (!await file.exists()) return null;
    final extension = localPath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final path = '$eventId/$transactionId.$extension';
    await client.storage
        .from('receipts')
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    return path;
  }

  /// Returns the active participant share token for [eventId].
  Future<String> createShareLink(String eventId) async {
    final token = await client.rpc(
      'create_share_link',
      params: {'p_event_id': eventId},
    );
    return token as String;
  }

  Future<void> revokeShareLinks(String eventId) async {
    await client.rpc('revoke_share_links', params: {'p_event_id': eventId});
  }

  /// Public read-only snapshot for a participant share link.
  Future<Map<String, dynamic>> fetchSharedCashbook(String token) async {
    final result = await client.rpc(
      'get_shared_cashbook',
      params: {'p_token': token},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Short-lived signed URL so members on other phones can see a receipt.
  Future<String?> receiptUrl(String storagePath) async {
    try {
      return await client.storage
          .from('receipts')
          .createSignedUrl(storagePath, 60 * 60);
    } catch (_) {
      return null;
    }
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
