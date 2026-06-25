
import 'package:flutter/material.dart';

void main() {
  runApp(const BaustellenApp());
}

////////////////////////////////////////////////////////////
// ✅ HAUPT APP
////////////////////////////////////////////////////////////

class BaustellenApp extends StatelessWidget {
  const BaustellenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baustellen Helfer',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const StartScreen(), // ✅ Einstieg ist Startseite
    );
  }
}

////////////////////////////////////////////////////////////
// ✅ CHECKLIST ITEM (falls noch nicht vorhanden)
////////////////////////////////////////////////////////////

class ChecklistItem {
  String text;
  bool isDone;

  ChecklistItem(this.text, {this.isDone = false});
}

////////////////////////////////////////////////////////////
// ✅ KONTAKT (Telefon + WhatsApp)
////////////////////////////////////////////////////////////

class ContactLink {
  String name;
  String phone; // wichtig für WhatsApp

  ContactLink(this.name, this.phone);
}

////////////////////////////////////////////////////////////
// ✅ ITEM (FINAL – mit Erstellungshistorie)
////////////////////////////////////////////////////////////

class Item {
  String type;      // "photo", "document", "video", "note"
  String content;   // Datei oder Text
  String name;      // Anzeigename

  DateTime createdAt;   // ✅ wann erstellt
  String createdBy;     // ✅ von wem erstellt

  //////////////////////////////////////////////////////////
  // ✅ Konstruktor
  //////////////////////////////////////////////////////////
  Item(
    this.type,
    this.content,
    this.name, {
    DateTime? createdAt,
    this.createdBy = "User", // später echter Nutzername
  }) : createdAt = createdAt ?? DateTime.now();
}

class Task {
  String id;

  String name;
  String description;

  String status;

  bool isHighPriority; // ✅ FINAL

  DateTime? dueDate;

  List<ChecklistItem> checklist;
  List<String> itemRefs;

  String createdBy;
  DateTime createdAt;
  DateTime updatedAt;

  Task(
    this.id,
    this.name, {
    this.description = "",
    this.status = "offen",
    this.isHighPriority = false, // ✅ Default
    this.dueDate,
    this.checklist = const [],
    this.itemRefs = const [],
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
////////////////////////////////////////////////////////////
// ✅ GEWERK (FINAL)
////////////////////////////////////////////////////////////

class Gewerk {
  String name;                      // ✅ einziges Pflichtfeld

  String? category;                // ✅ Kategorie (hidden / optional)

  List<Task> tasks;                // ✅ Aufgaben (optional)
  List<ChecklistItem> checklist;   // ✅ Gewerk-Checkliste

  List<Item> items;                // ✅ Dokumente, Fotos, Videos, Notizen

  List<ContactLink> contacts;      // ✅ Kontakte (Telefon/WhatsApp)

  Set<String> activeModules;       // ✅ steuert UI

////////////////////////////////////////////////////////////
// ✅ Konstruktor
////////////////////////////////////////////////////////////

Gewerk(
  this.name, {
  this.category,
  this.tasks = const [],
  this.checklist = const [],
  this.items = const [],
  this.contacts = const [],
  this.activeModules = const {"tasks", "contacts"},
});
}

////////////////////////////////////////////////////////////
// ✅ GEWERKE SCREEN
////////////////////////////////////////////////////////////

class GewerkeScreen extends StatefulWidget {
  const GewerkeScreen({super.key});

  @override
  State<GewerkeScreen> createState() => _GewerkeScreenState();
}

class _GewerkeScreenState extends State<GewerkeScreen> {

  // ✅ Start-Gewerke (werden später durch Nutzer ersetzt!)
  List<Gewerk> gewerke = [
    Gewerk("Rohbau"),
    Gewerk("Elektrik"),
    Gewerk("Sanitär"),
    Gewerk("Innen"),
    Gewerk("Außen"),
  ];

  // ✅ aktuell ausgewähltes Gewerk
  String selectedGewerk = "Rohbau";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Mein Haus", context, true),

      body: Column(
        children: [

          ////////////////////////////////////////////////////////////
          // ✅ GEWERKE TABS (jetzt dynamisch!)
          ////////////////////////////////////////////////////////////
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: gewerke.length,
              itemBuilder: (context, index) {

                final gewerk = gewerke[index];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedGewerk = gewerk.name;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(gewerk.name),
                    ),
                  ),
                );
              },
            ),
          ),

          ////////////////////////////////////////////////////////////
          // ✅ INHALT DES GEWERKS
          ////////////////////////////////////////////////////////////
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: buildGewerkContent(),
            ),
          )
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  // ✅ Inhalt eines Gewerks (JETZT dynamisch!)
  ////////////////////////////////////////////////////////////
  Widget buildGewerkContent() {

    // 👉 aktuelles Gewerk finden
    final current = gewerke.firstWhere((g) => g.name == selectedGewerk);

    return ListView(
      children: [

        // ✅ Gewerkname
        Text(
          current.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        ////////////////////////////////////////////////////////////
        // ✅ TO-DOS (JETZT dynamisch!)
        ////////////////////////////////////////////////////////////
        const Text("To-Dos", style: TextStyle(fontSize: 18)),

        ...current.tasks.map((task) {
          return taskWidget(task, context);
        }).toList(),

        const SizedBox(height: 20),

        ////////////////////////////////////////////////////////////
        // ✅ BUTTON → Aufgabe hinzufügen
        ////////////////////////////////////////////////////////////
        ElevatedButton(
          onPressed: () {
            showTaskDialog(current);
          },
          child: const Text("➕ Aufgabe hinzufügen"),
        ),
      ],
    );
  }

  ////////////////////////////////////////////////////////////
  // ✅ NEUE AUFGABE ERSTELLEN (JETZT FUNKTIONAL!)
  ////////////////////////////////////////////////////////////
  void showTaskDialog(Gewerk gewerk) {

    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Neue Aufgabe"),

          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Aufgabe eingeben",
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // ✅ neue Aufgabe wird zum Gewerk hinzugefügt
                  gewerk.tasks.add(
                      Task(
                        DateTime.now().millisecondsSinceEpoch.toString(), // ✅ id
                        controller.text, // ✅ name
                        status: "offen",
                        dueDate: DateTime.now().add(const Duration(days: 2)),
                        createdBy: "User", // ✅ wichtig!
                      ),
                  );
                });

                Navigator.pop(context);
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////
// ✅ STARTSEITE
////////////////////////////////////////////////////////////

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Baustellen Helfer", context, false),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GewerkeScreen(),
                ),
              );
            },
            child: projectCard(
              name: "Mein Haus",
              address: "Musterstraße 12",
              update: "⭐ Fenster bestellen",
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
// ✅ Projektkarte
////////////////////////////////////////////////////////////

Widget projectCard({
  required String name,
  required String address,
  required String update,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(address, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        Text(update),
      ],
    ),
  );
}

////////////////////////////////////////////////////////////
// ✅ UI BAUSTEINE
////////////////////////////////////////////////////////////

// ✅ AppBar (immer gleich)
PreferredSizeWidget buildAppBar(String title, BuildContext context, bool showBack) {
  return AppBar(
    title: Text(title),
    leading: showBack
        ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          )
        : null,
    actions: [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {},
      )
    ],
  );
}

// ✅ Box (für Tasks etc.)
Widget taskWidget(Task task, BuildContext context) {
  ////////////////////////////////////////////////////////////
  // ✅ FARBLOGIK
  ////////////////////////////////////////////////////////////

  Color color = Colors.white;

  if (task.status == "erledigt") {
    color = Colors.green.shade200;
  } else if (task.status == "teilweise") {
    color = Colors.blue.shade200;
  } else if (task.status == "archiviert") {
    color = Colors.grey.shade300;
  } 
  else if (task.status == "offen" && task.isHighPriority && task.dueDate != null) {
    final now = DateTime.now();
    final diff = task.dueDate!.difference(now).inDays;

    if (diff <= 1) {
      color = const Color(0xFFFFD6D6); // 🔴 kritisch
    } else if (diff <= 3) {
      color = const Color(0xFFFFF3CD); // 🟡 bald
    }
  }

  ////////////////////////////////////////////////////////////
  // ✅ STATUS ICON
  ////////////////////////////////////////////////////////////

  IconData icon;
  switch (task.status) {
    case "erledigt":
      icon = Icons.check_circle;
      break;
    case "teilweise":
      icon = Icons.radio_button_checked;
      break;
    case "archiviert":
      icon = Icons.archive;
      break;
    default:
      icon = Icons.circle_outlined;
  }

  ////////////////////////////////////////////////////////////
  // ✅ WIDGET
  ////////////////////////////////////////////////////////////

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(task: task),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          ////////////////////////////////////////////////////////////
          // ✅ ZEILE 1: STATUS + NAME + PRIO
          ////////////////////////////////////////////////////////////

          Row(
            children: [

              // ✅ Status klickbar
              IconButton(
                icon: Icon(icon),
                onPressed: () {
                  // Status wechseln (einfach gehalten)
                  if (task.status == "offen") {
                    task.status = "teilweise";
                  } else if (task.status == "teilweise") {
                    task.status = "erledigt";
                  } else if (task.status == "erledigt") {
                    task.status = "offen";
                  }
                },
              ),

              // ✅ Name + 🔥 Prio
              Expanded(
                child: Row(
                  children: [
                    if (task.isHighPriority)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text("🔥"),
                      ),
                    Expanded(
                      child: Text(
                        task.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          ////////////////////////////////////////////////////////////
          // ✅ BESCHREIBUNG
          ////////////////////////////////////////////////////////////

          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Text(
                task.description,
                style: const TextStyle(color: Colors.black87),
              ),
            ),

          ////////////////////////////////////////////////////////////
          // ✅ CHECKLISTE (gekürzt)
          ////////////////////////////////////////////////////////////

          ...task.checklist.take(3).map((item) {
            return Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Row(
                children: [
                  Icon(
                    item.isDone ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(item.text),
                ],
              ),
            );
          }).toList(),

          ////////////////////////////////////////////////////////////
          // ✅ DATUM + INFO
          ////////////////////////////////////////////////////////////

          Row(
            children: [

              const Spacer(),

              // ✅ Datum
              if (task.dueDate != null)
                Text(
                  "${task.dueDate!.day}.${task.dueDate!.month}",
                  style: const TextStyle(fontSize: 12),
                ),

              const SizedBox(width: 10),

              // ✅ Info Button (Mini Infos)
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Erstellt von: ${task.createdBy}\n"
                        "Erstellt am: ${task.createdAt}\n"
                        "Letzte Änderung: ${task.updatedAt}",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          ////////////////////////////////////////////////////////////
          // ✅ ACTION BUTTONS
          ////////////////////////////////////////////////////////////

          Row(
            children: [

              IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: () {
                  if (task.dueDate != null) {
                    task.dueDate =
                        task.dueDate!.add(const Duration(days: 1));
                  }
                },
              ),

              IconButton(
                icon: const Icon(Icons.archive),
                onPressed: () {
                  task.status = "archiviert";
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // ✅ Status Icon
  IconData icon = Icons.circle_outlined;
  switch (task.status) {
    case "erledigt":
      icon = Icons.check_circle;
      break;
    case "teilweise":
      icon = Icons.radio_button_checked;
      break;
    case "archiviert":
      icon = Icons.archive;
      break;
    default:
      icon = Icons.circle_outlined;
  }

  return Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [

        // ✅ Text
        Expanded(child: Text(task.name)),

        // ✅ Status Icon
        Icon(icon),

        // ✅ Buttons
        IconButton(
          icon: const Icon(Icons.schedule),
          onPressed: () {

            if (task.dueDate != null) {

              DateTime newDate =
                  task.dueDate!.add(Duration(days: defaultShiftDays));

              // ✅ prüfen ob Sonntag / Feiertag
              newDate = adjustDate(newDate, context);

              task.dueDate = newDate;
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.archive),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {},
        ),
      ],
    ),
  );
}
// ✅ Globale Einstellung (später aus Settings laden)
int defaultShiftDays = 3;

// ✅ Datum prüfen und ggf. verschieben
DateTime adjustDate(DateTime date, BuildContext context) {

  // Sonntag prüfen
  bool isSunday = date.weekday == DateTime.sunday;

  // 👉 Vereinfachter Feiertag (Beispiel – später erweiterbar)
  bool isHoliday = false;

  if (isSunday || isHoliday) {

    // Hinweis anzeigen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Achtung: Sonntag/Feiertag → Datum +1 Tag nach hinten verschoben"),
      ),
    );

    return date.add(const Duration(days: 1));
  }

  return date;
}
////////////////////////////////////////////////////////////
// ✅ TASK DETAIL SCREEN
////////////////////////////////////////////////////////////

class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Aufgabe", context, true),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          ////////////////////////////////////////////////////////////
          // ✅ Titel + Status
          ////////////////////////////////////////////////////////////
          Text(
            task.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Text("Status: ${task.status}"),

          const SizedBox(height: 10),

          
          if (task.dueDate != null)
            ...[
              Text("Fällig: ${task.dueDate}"),
              const SizedBox(height: 20),


          ////////////////////////////////////////////////////////////
          // ✅ Beschreibung (placeholder)
          ////////////////////////////////////////////////////////////
          const Text("Beschreibung"),
          const SizedBox(height: 5),
          const Text("Hier können später Details stehen."),

          const SizedBox(height: 20),

          ////////////////////////////////////////////////////////////
          // ✅ Dokumente
          ////////////////////////////////////////////////////////////
          const Text("Dokumente"),
          boxDummy("📄 Angebot.pdf"),
          boxDummy("📄 Rechnung.pdf"),

          const SizedBox(height: 20),

          ////////////////////////////////////////////////////////////
          // ✅ Fotos
          ////////////////////////////////////////////////////////////
          const Text("Fotos"),
          boxDummy("📸 Baustelle 01"),
          boxDummy("📸 Baustelle 02"),

          const SizedBox(height: 20),

          ////////////////////////////////////////////////////////////
          // ✅ Notizen
          ////////////////////////////////////////////////////////////
          const Text("Notizen"),
          const Text("Noch keine Notizen vorhanden"),

        ],
        ],
      )
    );
  }
}
// ✅ einfache Anzeige für Dokumente / Fotos im Detailscreen
Widget boxDummy(String text) {
  return Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text),
  );
}