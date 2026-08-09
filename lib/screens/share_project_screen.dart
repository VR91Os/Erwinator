import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_member.dart';
import '../services/sharing_service.dart';
import '../state/project_store.dart';
import '../widgets/app_bar.dart';

// Für den Ersteller: zeigt Einladungscode + QR-Code zum Teilen und die
// Liste offener Beitrittsanfragen (live, mit Bestätigen/Ablehnen).
class ShareProjectScreen extends StatefulWidget {
  final String projectId;

  const ShareProjectScreen({super.key, required this.projectId});

  @override
  State<ShareProjectScreen> createState() => _ShareProjectScreenState();
}

class _ShareProjectScreenState extends State<ShareProjectScreen> {
  final _sharingService = SharingService();
  bool _loading = true;
  String? _sharedId;
  String? _error;
  List<ProjectMember> _pending = [];
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final store = context.read<ProjectStore>();
      final project =
          store.projects.firstWhere((p) => p.id == widget.projectId);
      final sharedId = project.sharedId ??
          await store.shareProject(widget.projectId);
      if (!mounted) return;
      setState(() {
        _sharedId = sharedId;
        _loading = false;
      });
      await _loadPending();
      _subscription = _sharingService.subscribeToPendingMembers(
        sharedId,
        () => _loadPending(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Teilen fehlgeschlagen: $e";
        _loading = false;
      });
    }
  }

  Future<void> _loadPending() async {
    final sharedId = _sharedId;
    if (sharedId == null) return;
    final members = await _sharingService.pendingMembers(sharedId);
    if (mounted) setState(() => _pending = members);
  }

  Future<void> _decide(ProjectMember member, bool approve) async {
    await _sharingService.decideMembership(member.id, approve: approve);
    _loadPending();
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) _sharingService.unsubscribe(subscription);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Projekt teilen", context, true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      "Einladungscode",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Die Person gibt diesen Code unter \"Projekt beitreten\" "
                      "ein oder scannt den QR-Code.",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: QrImageView(data: _sharedId!, size: 220),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SelectableText(
                        _sharedId!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Share.share(
                          'Tritt meinem Baustelli-Projekt bei! Code: $_sharedId',
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text("Einladung teilen"),
                      ),
                    ),
                    const Divider(height: 40),
                    const Text(
                      "Offene Beitrittsanfragen",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text("Keine offenen Anfragen"),
                      ),
                    ..._pending.map((member) {
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(member.displayName),
                        subtitle: member.kurzzeichen == null
                            ? null
                            : Text("Kürzel: ${member.kurzzeichen}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check,
                                  color: Colors.green),
                              tooltip: "Bestätigen",
                              onPressed: () => _decide(member, true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: "Ablehnen",
                              onPressed: () => _decide(member, false),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
