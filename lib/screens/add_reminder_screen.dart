import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/reminder_service.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? existingReminder;

  const AddReminderScreen({Key? key, this.existingReminder}) : super(key: key);

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _nameController = TextEditingController();

  TimeOfDay? _selectedTime;
  ReminderType _selectedType = ReminderType.daily;
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];
  DateTime? _selectedDate;
  bool _isEnabled = true;
  final List<String> _availableSounds = [
    'assets/sounds/reminder.mp3',
  ];
  String? _selectedSound;

  bool get _isEditMode => widget.existingReminder != null;

  @override
  void initState() {
    super.initState();
    _selectedSound = _availableSounds[0];
    _loadExistingReminder();
  }

  void _loadExistingReminder() {
    final reminder = widget.existingReminder;
    if (reminder == null) return;

    _nameController.text = reminder.name;
    _selectedTime = TimeOfDay(
      hour: reminder.time.hour,
      minute: reminder.time.minute,
    );
    _selectedType = reminder.type;
    _selectedDays = List<int>.from(reminder.days);
    _selectedDate = reminder.customDate;
    _isEnabled = reminder.isEnabled;
    _selectedSound = reminder.soundPath;
  }

  void _applyPreset(String name) {
    setState(() {
      _nameController.text = name;
      _selectedType = ReminderType.weekdays;
      _selectedDays = [1, 2, 3, 4, 5];
      _selectedDate = null;
      _isEnabled = true;
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    final initialTime = _selectedTime ?? TimeOfDay.now();
    var pickedTime = initialTime;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) {
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(popupContext).pop(),
                      child: const Text('取消'),
                    ),
                    const Text(
                      '选择时间',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTime = pickedTime;
                        });
                        Navigator.of(popupContext).pop();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    2024,
                    1,
                    1,
                    initialTime.hour,
                    initialTime.minute,
                  ),
                  onDateTimeChanged: (value) {
                    pickedTime = TimeOfDay(hour: value.hour, minute: value.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _testSound() async {
    try {
      await ReminderService().testSound();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发送系统测试提醒，请检查通知和声音')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('测试失败: $e')),
      );
    }
  }

  Future<void> _saveReminder() async {
    if (_nameController.text.isEmpty || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写提醒名称和时间')),
      );
      return;
    }

    if (_selectedType == ReminderType.specificDate && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择指定日期')),
      );
      return;
    }

    if (_selectedType == ReminderType.custom && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自定义提醒至少选择一天')),
      );
      return;
    }

    final reminder = Reminder(
      id: widget.existingReminder?.id ?? 0,
      name: _nameController.text.trim(),
      time: TimeSetting(_selectedTime!.hour, _selectedTime!.minute),
      days: _selectedType == ReminderType.weekdays
          ? [1, 2, 3, 4, 5]
          : List<int>.from(_selectedDays),
      isEnabled: _isEnabled,
      soundPath: _selectedSound!,
      type: _selectedType,
      customDate: _selectedType == ReminderType.specificDate ? _selectedDate : null,
    );

    try {
      if (_isEditMode) {
        await _dbHelper.updateReminder(reminder);
        if (mounted) {
          Navigator.pop(context, true);
        }
        ReminderService().rescheduleReminderInBackground(reminder);
      } else {
        final reminderId = await _dbHelper.insertReminder(reminder);
        final createdReminder = Reminder(
          id: reminderId,
          name: reminder.name,
          time: reminder.time,
          days: reminder.days,
          isEnabled: reminder.isEnabled,
          soundPath: reminder.soundPath,
          type: reminder.type,
          customDate: reminder.customDate,
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
        if (createdReminder.isEnabled) {
          ReminderService().scheduleReminderInBackground(createdReminder);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Widget _buildPresetSection() {
    if (_isEditMode) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快速模板',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _applyPreset('上班提醒'),
                icon: const Icon(Icons.work_outline),
                label: const Text('上班提醒'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _applyPreset('下班提醒'),
                icon: const Icon(Icons.nightlight_round),
                label: const Text('下班提醒'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDaySelector() {
    if (_selectedType != ReminderType.custom) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('选择星期:'),
        Wrap(
          children: List<Widget>.generate(7, (index) {
            final day = index + 1;
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: FilterChip(
                label: Text(['一', '二', '三', '四', '五', '六', '日'][index]),
                selected: _selectedDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (!_selectedDays.contains(day)) {
                        _selectedDays.add(day);
                      }
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDateSelector() {
    if (_selectedType != ReminderType.specificDate) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            const Text('选择日期: '),
            TextButton(
              onPressed: () => _selectDate(context),
              child: Text(
                _selectedDate == null
                    ? '选择日期'
                    : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑提醒' : '添加提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveReminder,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPresetSection(),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '提醒名称',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入提醒名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('时间: '),
                    TextButton(
                      onPressed: () => _selectTime(context),
                      child: Text(
                        _selectedTime == null
                            ? '选择时间'
                            : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('提醒类型:'),
                RadioListTile<ReminderType>(
                  title: const Text('每天'),
                  value: ReminderType.daily,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                RadioListTile<ReminderType>(
                  title: const Text('工作日'),
                  value: ReminderType.weekdays,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                      _selectedDays = [1, 2, 3, 4, 5];
                    });
                  },
                ),
                RadioListTile<ReminderType>(
                  title: const Text('自定义'),
                  value: ReminderType.custom,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                RadioListTile<ReminderType>(
                  title: const Text('指定日期'),
                  value: ReminderType.specificDate,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                _buildDaySelector(),
                _buildDateSelector(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用提醒'),
                  value: _isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isEnabled = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('提醒声音:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSound,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _availableSounds.map((sound) {
                    return DropdownMenuItem<String>(
                      value: sound,
                      child: Text(sound.split('/').last.replaceAll('.mp3', '')),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedSound = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _selectedSound != null ? _testSound : null,
                  child: const Text('测试声音'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}