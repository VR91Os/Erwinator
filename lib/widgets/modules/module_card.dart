import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';

class ModuleCard extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final String moduleId;
  final String title;
  final Widget child;

  const ModuleCard({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.moduleId,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: "Modul entfernen",
                onPressed: () {
                  context
                      .read<ProjectStore>()
                      .removeModule(projectId, gewerkId, moduleId);
                },
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
