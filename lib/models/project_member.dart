// Beitrittsanfrage/Mitgliedschaft zu einem geteilten Projekt. Spiegelt
// eine Zeile der Supabase-Tabelle "project_members" – lebt nur in der
// Cloud, wird nicht lokal persistiert.
class ProjectMember {
  static const statusPending = 'pending';
  static const statusApproved = 'approved';
  static const statusRejected = 'rejected';

  String id;
  String projectId;
  String userId;
  String displayName;
  String? kurzzeichen;
  String status;
  DateTime invitedAt;

  ProjectMember({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.displayName,
    this.kurzzeichen,
    this.status = statusPending,
    required this.invitedAt,
  });

  factory ProjectMember.fromMap(Map<String, dynamic> map) => ProjectMember(
        id: map['id'] as String,
        projectId: map['project_id'] as String,
        userId: map['user_id'] as String,
        displayName: map['display_name'] as String? ?? '',
        kurzzeichen: map['kurzzeichen'] as String?,
        status: map['status'] as String? ?? statusPending,
        invitedAt: DateTime.parse(map['invited_at'] as String),
      );
}
