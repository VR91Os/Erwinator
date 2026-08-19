import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/utils/safe_notify.dart';

// popDialogThen/deferredNotify sind der zentrale Fix für den
// "_dependents.isEmpty"-Crash (Store-Mutation kollidiert mit dem
// Element-Abbau eines sich schließenden Dialogs, wenn beides synchron im
// selben Callback läuft). Dieser Test prüft direkt den Vertrag der
// Utility: die übergebene Funktion darf erst NACH dem aktuellen Frame
// laufen, nie synchron im selben Callback wie Navigator.pop.
void main() {
  testWidgets(
      'popDialogThen schließt den Dialog sofort, ruft mutate aber erst nach dem nächsten Frame auf',
      (tester) async {
    var mutateCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                actions: [
                  ElevatedButton(
                    onPressed: () => popDialogThen(
                        dialogContext, () => mutateCalled = true),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    // Direkt nach dem Tap (vor dem nächsten Frame) darf mutate noch nicht
    // gelaufen sein - genau das ist der Zweck von popDialogThen.
    expect(mutateCalled, isFalse);

    await tester.pump();
    expect(mutateCalled, isTrue);

    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('deferredNotify ruft die Funktion erst nach dem nächsten Frame auf',
      (tester) async {
    var called = false;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    deferredNotify(() => called = true);
    expect(called, isFalse);

    await tester.pump();
    expect(called, isTrue);
  });
}
