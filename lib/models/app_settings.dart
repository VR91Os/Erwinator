import 'team_member.dart';

class AppSettings {
  bool jumpToLastProject;
  String? lastProjectId;

  String userName;
  String userInitials;
  String googleAccountEmail; // nur gespeichert, noch keine echte Anmeldung

  // Steuert, ob das (i)-Verlaufs-Icon (wer hat erstellt/bearbeitet/abgehakt)
  // in den Modulen angezeigt wird.
  bool showAuthorInfo;

  List<TeamMember> invitedUsers; // nur lokale Liste, noch kein echter Versand

  AppSettings({
    this.jumpToLastProject = true,
    this.lastProjectId,
    this.userName = '',
    this.userInitials = '',
    this.googleAccountEmail = '',
    this.showAuthorInfo = true,
    List<TeamMember>? invitedUsers,
  }) : invitedUsers = invitedUsers ?? [];

  Map<String, dynamic> toMap() => {
        'jumpToLastProject': jumpToLastProject,
        'lastProjectId': lastProjectId,
        'userName': userName,
        'userInitials': userInitials,
        'googleAccountEmail': googleAccountEmail,
        'showAuthorInfo': showAuthorInfo,
        'invitedUsers': invitedUsers.map((u) => u.toMap()).toList(),
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        jumpToLastProject: map['jumpToLastProject'] as bool? ?? true,
        lastProjectId: map['lastProjectId'] as String?,
        userName: map['userName'] as String? ?? '',
        userInitials: map['userInitials'] as String? ?? '',
        googleAccountEmail: map['googleAccountEmail'] as String? ?? '',
        showAuthorInfo: map['showAuthorInfo'] as bool? ?? true,
        invitedUsers: (map['invitedUsers'] as List<dynamic>? ?? [])
            .map((e) => TeamMember.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
