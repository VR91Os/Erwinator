import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project.dart';
import '../models/project_member.dart';

// Kapselt alle Supabase-Zugriffe fürs Projekt-Teilen: anonymer Login,
// Projekt in die Cloud legen/aktualisieren, Beitrittsanfragen stellen,
// offene Anfragen bestätigen/ablehnen, Live-Updates per Realtime.
class SharingService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> ensureSignedIn() async {
    final session = _client.auth.currentSession;
    if (session != null) return session.user.id;
    final response = await _client.auth.signInAnonymously();
    return response.user!.id;
  }

  // Legt eine neue shared_projects-Zeile an (falls project.sharedId noch
  // nicht gesetzt ist) oder aktualisiert die bestehende. Gibt die
  // shared_projects-ID zurück.
  Future<String> shareProject(Project project) async {
    final userId = await ensureSignedIn();
    if (project.sharedId != null) {
      await pushUpdate(project.sharedId!, project);
      return project.sharedId!;
    }
    final row = await _client
        .from('shared_projects')
        .insert({
          'local_project_id': project.id,
          'owner_id': userId,
          'data': project.toMap(),
        })
        .select()
        .single();
    return row['id'] as String;
  }

  Future<void> pushUpdate(String sharedId, Project project) async {
    await _client.from('shared_projects').update({
      'data': project.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sharedId);
  }

  Future<Project?> fetchSharedProject(String sharedId) async {
    final row = await _client
        .from('shared_projects')
        .select()
        .eq('id', sharedId)
        .maybeSingle();
    if (row == null) return null;
    final project =
        Project.fromMap(row['data'] as Map<String, dynamic>);
    project.sharedId = sharedId;
    return project;
  }

  Future<void> requestToJoin(
    String sharedId, {
    required String displayName,
    String? kurzzeichen,
  }) async {
    final userId = await ensureSignedIn();
    await _client.from('project_members').upsert(
      {
        'project_id': sharedId,
        'user_id': userId,
        'display_name': displayName,
        'kurzzeichen': kurzzeichen,
        'status': ProjectMember.statusPending,
      },
      onConflict: 'project_id,user_id',
    );
  }

  // '' = noch keine Anfrage gestellt.
  Future<String> myMembershipStatus(String sharedId) async {
    final userId = await ensureSignedIn();
    final row = await _client
        .from('project_members')
        .select()
        .eq('project_id', sharedId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? '' : row['status'] as String;
  }

  Future<List<ProjectMember>> pendingMembers(String sharedId) async {
    final rows = await _client
        .from('project_members')
        .select()
        .eq('project_id', sharedId)
        .eq('status', ProjectMember.statusPending);
    return (rows as List)
        .map((r) => ProjectMember.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> decideMembership(String memberId, {required bool approve}) async {
    await _client.from('project_members').update({
      'status':
          approve ? ProjectMember.statusApproved : ProjectMember.statusRejected,
      'decided_at': DateTime.now().toIso8601String(),
    }).eq('id', memberId);
  }

  RealtimeChannel subscribeToPendingMembers(
    String sharedId,
    void Function() onChange,
  ) {
    return _client
        .channel('members_$sharedId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'project_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: sharedId,
          ),
          callback: (payload) => onChange(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToProjectUpdates(
    String sharedId,
    void Function(Project) onUpdate,
  ) {
    return _client
        .channel('project_$sharedId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'shared_projects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sharedId,
          ),
          callback: (payload) {
            final data = payload.newRecord['data'] as Map<String, dynamic>;
            final project = Project.fromMap(data);
            project.sharedId = sharedId;
            onUpdate(project);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToMyMembership(
    String sharedId,
    String userId,
    void Function(String status) onChange,
  ) {
    return _client
        .channel('my_membership_${sharedId}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'project_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord['project_id'] != sharedId) return;
            onChange(payload.newRecord['status'] as String);
          },
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
