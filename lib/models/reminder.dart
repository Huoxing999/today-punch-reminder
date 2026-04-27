class Reminder {
  final int id;
  final String name;
  final TimeSetting time;
  final List<int> days;
  final bool isEnabled;
  final String soundPath;
  final ReminderType type;
  final DateTime? customDate;
  final ItemType itemType;
  final bool isCompleted;
  final DateTime? completedDate;
  final DateTime? dueDate;

  Reminder({
    required this.id,
    required this.name,
    required this.time,
    required this.days,
    required this.isEnabled,
    required this.soundPath,
    required this.type,
    this.customDate,
    this.itemType = ItemType.reminder,
    this.isCompleted = false,
    this.completedDate,
    this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hour': time.hour,
      'minute': time.minute,
      'days': days.join(','),
      'isEnabled': isEnabled ? 1 : 0,
      'soundPath': soundPath,
      'type': type.index,
      'customDate': customDate?.millisecondsSinceEpoch,
      'itemType': itemType.index,
      'isCompleted': isCompleted ? 1 : 0,
      'completedDate': completedDate?.millisecondsSinceEpoch,
      'dueDate': dueDate?.millisecondsSinceEpoch,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final daysText = (map['days'] ?? '').toString();
    return Reminder(
      id: map['id'],
      name: map['name'],
      time: TimeSetting(map['hour'], map['minute']),
      days: daysText.isEmpty ? <int>[] : daysText.split(',').map(int.parse).toList(),
      isEnabled: map['isEnabled'] == 1,
      soundPath: map['soundPath'],
      type: ReminderType.values[map['type']],
      customDate: map['customDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['customDate'])
          : null,
      itemType: ItemType.values[map['itemType'] ?? 0],
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      completedDate: map['completedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedDate'])
          : null,
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
          : null,
    );
  }
}

class TimeSetting {
  final int hour;
  final int minute;

  TimeSetting(this.hour, this.minute);
}

enum ReminderType {
  daily,
  weekdays,
  custom,
  specificDate,
}

enum ItemType {
  reminder,
  todo,
}
