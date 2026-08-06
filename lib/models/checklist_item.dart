class ChecklistItem {
  String text;
  bool isDone;

  ChecklistItem(this.text, {this.isDone = false});

  Map<String, dynamic> toMap() => {
        'text': text,
        'isDone': isDone,
      };

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        map['text'] as String,
        isDone: map['isDone'] as bool? ?? false,
      );
}
