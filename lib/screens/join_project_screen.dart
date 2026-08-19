import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_member.dart';
import '../services/sharing_service.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../widgets/app_bar.dart';
import 'qr_scan_screen.dart';

// Für die eingeladene Person: Einladungscode + Name eingeben, Anfrage
// senden, warten bis der Ersteller bestätigt (live), danach wird das
// Projekt automatisch lokal übernommen.
class JoinProjectScreen extends StatefulWidget {
  const JoinProjectScreen({super.key});

  @override
  State<JoinProjectScreen> createState() => _JoinProjectScreenState();
}

class _JoinProjectScreenState extends State<JoinProjectScreen> {
  final _sharingService = SharingService();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _requested = false;
  bool _loading = false;
  String? _error;
  RealtimeChannel? _subscription;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    final subscription = _subscription;
    if (subscription != null) _sharingService.unsubscribe(subscription);
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScanScreen()),
    );
    if (scanned != null && scanned.isNotEmpty) {
      _codeController.text = scanned;
    }
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await _sharingService.ensureSignedIn();
      final existingStatus = await _sharingService.myMembershipStatus(code);
      if (existingStatus == ProjectMember.statusApproved) {
        // Bereits Mitglied (z.B. Code/QR erneut eingegeben) – nicht erneut
        // anfragen, das würde den Status sonst auf "pending" zurücksetzen.
        if (!mounted) return;
        await _onApproved(code);
        return;
      }
      if (existingStatus != ProjectMember.statusPending) {
        if (!mounted) return;
        final settings = context.read<SettingsStore>().settings;
        await _sharingService.requestToJoin(
          code,
          displayName: name,
          kurzzeichen:
              settings.userInitials.isEmpty ? null : settings.userInitials,
        );
      }
      if (!mounted) return;
      setState(() {
        _requested = true;
        _loading = false;
      });
      _subscription = _sharingService.subscribeToMyMembership(
        code,
        userId,
        (status) {
          if (status == ProjectMember.statusApproved) {
            _onApproved(code);
          } else if (status == ProjectMember.statusRejected) {
            if (mounted) {
              setState(() => _error = "Beitrittsanfrage wurde abgelehnt.");
            }
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Anfrage fehlgeschlagen – Code korrekt? ($e)";
        _loading = false;
      });
    }
  }

  Future<void> _onApproved(String sharedId) async {
    final project = await _sharingService.fetchSharedProject(sharedId);
    if (project == null || !mounted) return;
    await context.read<ProjectStore>().addSharedProject(project);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Projekt "${project.name}" beigetreten')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Projekt beitreten", context, true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _requested
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      "Warte auf Bestätigung durch den Ersteller…",
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Einladungscode eintragen oder QR-Code scannen.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _scanQrCode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("QR-Code scannen"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    decoration:
                        const InputDecoration(labelText: "Einladungscode *"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Dein Name *"),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child:
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Beitreten anfragen"),
                  ),
                ],
              ),
      ),
    );
  }
}
