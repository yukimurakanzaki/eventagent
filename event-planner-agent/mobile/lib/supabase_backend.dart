import 'package:supabase_flutter/supabase_flutter.dart';

import 'cashbook_models.dart';
import 'cashbook_sync.dart';

class SupabaseBackend {
  SupabaseBackend(this.client);

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const authRedirectUrl = 'io.wargakas.mobile://auth-callback/';

  final SupabaseClient client;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<SupabaseBackend?> initializeFromEnvironment() async {
    if (!isConfigured) return null;
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    );
    return SupabaseBackend(Supabase.instance.client);
  }

  User? get user => client.auth.currentUser;

  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String email, String password) async {
    await client.auth.signUp(
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

  Future<void> signOut() => client.auth.signOut();

  Future<SupabaseCashbookSyncAdapter> openCashbook(CashbookSnapshot seed) async {
    final membership = await client
        .from('workspace_members')
        .select('workspace_id')
        .order('created_at')
        .limit(1)
        .maybeSingle();

    if (membership == null) {
      final created = await client.rpc(
        'create_workspace_with_event',
        params: {
          'p_workspace_name': 'Wargakas',
          'p_snapshot': seed.toJson(),
        },
      );
      final data = Map<String, dynamic>.from(created as Map);
      return SupabaseCashbookSyncAdapter(
        client: client,
        workspaceId: data['workspace_id'] as String,
        eventId: data['event_id'] as String,
      );
    }

    final workspaceId = membership['workspace_id'] as String;
    final event = await client
        .from('events')
        .select('id')
        .eq('workspace_id', workspaceId)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (event == null) {
      throw StateError('Akun belum memiliki acara. Buat acara pertama melalui dashboard Supabase.');
    }
    return SupabaseCashbookSyncAdapter(
      client: client,
      workspaceId: workspaceId,
      eventId: event['id'] as String,
    );
  }

  Future<void> inviteChairperson({required String workspaceId, required String email}) async {
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

class SupabaseCashbookSyncAdapter implements CashbookSyncAdapter {
  const SupabaseCashbookSyncAdapter({required this.client, required this.workspaceId, required this.eventId});

  final SupabaseClient client;
  final String workspaceId;
  final String eventId;

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
  Future<SyncResult> push({required CashbookSnapshot snapshot, required SyncOperation operation}) async {
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
        remoteSnapshot: CashbookSnapshot.fromJson(
          Map<String, dynamic>.from(data['snapshot'] as Map),
        ).copyWith(syncVersion: version),
      );
    }
    return SyncResult.synced(version: version);
  }
}
