class AppSettings {
  bool jumpToLastProject;
  String? lastProjectId;

  String userName;
  String userInitials;
  String googleAccountEmail; // nur gespeichert, noch keine echte Anmeldung

  List<String> invitedUsers; // nur lokale Liste, noch kein echter Versand

  AppSettings({
    this.jumpToLastProject = false,
    this.lastProjectId,
    this.userName = '',
    this.userInitials = '',
    this.googleAccountEmail = '',
    List<String>? invitedUsers,
  }) : invitedUsers = invitedUsers ?? [];

  Map<String, dynamic> toMap() => {
        'jumpToLastProject': jumpToLastProject,
        'lastProjectId': lastProjectId,
        'userName': userName,
        'userInitials': userInitials,
        'googleAccountEmail': googleAccountEmail,
        'invitedUsers': invitedUsers,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        jumpToLastProject: map['jumpToLastProject'] as bool? ?? false,
        lastProjectId: map['lastProjectId'] as String?,
        userName: map['userName'] as String? ?? '',
        userInitials: map['userInitials'] as String? ?? '',
        googleAccountEmail: map['googleAccountEmail'] as String? ?? '',
        invitedUsers: (map['invitedUsers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}
