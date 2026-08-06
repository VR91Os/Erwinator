import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/start_screen.dart';
import 'state/project_store.dart';
import 'state/settings_store.dart';

void main() {
  runApp(const BaustellenApp());
}

class BaustellenApp extends StatelessWidget {
  const BaustellenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectStore()..init()),
        ChangeNotifierProvider(create: (_) => SettingsStore()..init()),
      ],
      child: MaterialApp(
        title: 'Erwin der Baustellen Helfer',
        theme: ThemeData(
          primarySwatch: Colors.grey,
        ),
        home: const StartScreen(),
      ),
    );
  }
}
