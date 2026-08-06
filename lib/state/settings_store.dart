import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore({SettingsRepository? repository})
      : _repository = repository ?? LocalSettingsRepository();

  final SettingsRepository _repository;

  AppSettings settings = AppSettings();
  bool isLoading = true;

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
    await _persist();
  }

  Future<void> updateProfile({
    required String userName,
    required String userInitials,
    required String googleAccountEmail,
  }) async {
    settings.userName = userName;
    settings.userInitials = userInitials;
    settings.googleAccountEmail = googleAccountEmail;
    notifyListeners();
    await _persist();
  }

  Future<void> addInvitedUser(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || settings.invitedUsers.contains(trimmed)) return;
    settings.invitedUsers.add(trimmed);
    notifyListeners();
    await _persist();
  }

  Future<void> removeInvitedUser(String value) async {
    settings.invitedUsers.remove(value);
    notifyListeners();
    await _persist();
  }
}
