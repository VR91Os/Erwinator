import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/contact_module.dart';
import '../../state/project_store.dart';
import 'module_card.dart';

class ContactModuleWidget extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final ContactModule module;

  const ContactModuleWidget({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      projectId: projectId,
      gewerkId: gewerkId,
      moduleId: module.id,
      title: "📇 Kontakt",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: module.name,
            decoration: const InputDecoration(labelText: "Name"),
            onFieldSubmitted: (value) {
              context.read<ProjectStore>().updateContactModule(
                    projectId,
                    gewerkId,
                    module.id,
                    name: value,
                    phone: module.phone,
                  );
            },
          ),
          TextFormField(
            initialValue: module.phone,
            decoration: const InputDecoration(labelText: "Telefonnummer"),
            keyboardType: TextInputType.phone,
            onFieldSubmitted: (value) {
              context.read<ProjectStore>().updateContactModule(
                    projectId,
                    gewerkId,
                    module.id,
                    name: module.name,
                    phone: value,
                  );
            },
          ),
        ],
      ),
    );
  }
}
