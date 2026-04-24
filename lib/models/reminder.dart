class Reminder {
  final int id;
  final String name;
  final TimeSetting time;
  final List<int> days;
  final bool isEnabled;
  final String soundPath;
  final ReminderType type;
  final DateTime? customDate;

  Reminder({
    required this.id,
    required this.name,
    required this.time,
    required this.days,
    required this.isEnabled,
    required this.soundPath,
    required this.type,
    this.customDate,
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
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      name: map['name'],
      time: TimeSetting(map['hour'], map['minute']),
      days: map['days'].toString().split(',').map(int.parse).toList(),
      isEnabled: map['isEnabled'] == 1,
      soundPath: map['soundPath'],
      type: ReminderType.values[map['type']],
      customDate: map['customDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['customDate'])
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