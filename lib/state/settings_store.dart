import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/team_member.dart';
import '../repositories/settings_repository.dart';
import '../utils/id_generator.dart';
import '../utils/kurzzeichen.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore({SettingsRepository? repository})
      : _repository = repository ?? LocalSettingsRepository();

  final SettingsRepository _repository;

  AppSettings settings = AppSettings();
  bool isLoading = true;

  // Kurzzeichen für Aktionen des lokalen Nutzers, mit Fallback solange kein
  // Profil angelegt wurde.
  String get currentUserKurzzeichen =>
      settings.userInitials.isEmpty ? '??' : settings.userInitials;

  // Anzeigename für Listen (z.B. "Ich bin auf der Baustelle"), fällt auf
  // das Kurzzeichen zurück, solange kein Profilname hinterlegt ist.
  String get currentUserDisplayName =>
      settings.userName.trim().isEmpty
          ? currentUserKurzzeichen
          : settings.userName.trim();

  Future<void> init() async {
    // Auf Plattformen ohne Dateisystem-Zugriff (z.B. Web) bleibt die App
    // ohne Persistenz nutzbar, statt beim Start abzustürzen.
    try {
      settings = await _repository.loadSettings();
    } catch (_) {
      settings = AppSettings();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _repository.saveSettings(settings);
    } catch (_) {}
  }

  Future<void> setJumpToLastProject(bool value) async {
    settings.jumpToLastProject = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setLastProject(String projectId) async {
    if (settings.lastProjectId == projectId) return;
    settings.lastProjectId = projectId;
    notifyListeners();
    await _persist();
  }

  Future<void> setShowAuthorInfo(bool value) async {
    settings.showAuthorInfo = value;
    notifyListeners();
    await _persist();
  }

  // Das Kurzzeichen wird immer automatisch aus dem Namen erzeugt (2
  // Buchstaben Vorname + 2 Buchstaben Nachname) und bei Kollision mit einem
  // bereits bekannten Teammitglied eindeutig gemacht.
  Future<void> updateProfile({
    required String userName,
    required String googleAccountEmail,
  }) async {
    settings.userName = userName;
    settings.userInitials = generateKurzzeichen(
      userName,
      settings.invitedUsers.map((u) => u.kurzzeichen),
    );
    settings.googleAccountEmail = googleAccountEmail;
    notifyListeners();
    await _persist();
  }

  Future<void> addInvitedUser({
    required String name,
    String email = '',
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final existingKurzzeichen = [
      settings.userInitials,
      ...settings.invitedUsers.map((u) => u.kurzzeichen),
    ];
    settings.invitedUsers.add(TeamMember(
      id: newId(),
      name: trimmedName,
      email: email.trim(),
      kurzzeichen: generateKurzzeichen(trimmedName, existingKurzzeichen),
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> removeInvitedUser(String id) async {
    settings.invitedUsers.removeWhere((u) => u.id == id);
    notifyListeners();
    await _persist();
  }

  bool hasSeenFeatureHint(String key) =>
      settings.seenFeatureHints.contains(key);

  Future<void> markFeatureHintSeen(String key) async {
    if (settings.seenFeatureHints.contains(key)) return;
    settings.seenFeatureHints.add(key);
    notifyListeners();
    await _persist();
  }

  Future<void> setHolidayCountry(String countryCode) async {
    settings.holidayCountry = countryCode;
    notifyListeners();
    await _persist();
  }
}
