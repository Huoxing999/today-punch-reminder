import 'package:flutter/material.dart';
import '../services/database_service.dart';

class PunchRecordScreen extends StatefulWidget {
  final int reminderId;

  const PunchRecordScreen({Key? key, required this.reminderId}) : super(key: key);

  @override
  State<PunchRecordScreen> createState() => _PunchRecordScreenState();
}

class _PunchRecordScreenState extends State<PunchRecordScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<DateTime> _punchRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPunchRecords();
  }

  Future<void> _loadPunchRecords() async {
    final records = await _dbHelper.getPunchRecords(widget.reminderId);
    records.sort((a, b) => b.compareTo(a));
    setState(() {
      _punchRecords = records;
    });
  }

  Future<void> _recordPunch() async {
    final now = DateTime.now();
    await _dbHelper.insertPunchRecord(widget.reminderId, now);
    _loadPunchRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('打卡记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _recordPunch,
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '打卡记录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _punchRecords.isEmpty
                ? const Center(
                    child: Text(
                      '暂无打卡记录',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _punchRecords.length,
                    itemBuilder: (context, index) {
                      final record = _punchRecords[index];
                      return ListTile(
                        title: Text(
                          '${record.year}-${record.month.toString().padLeft(2, '0')}-${record.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: Text(
                          '${record.hour.toString().padLeft(2, '0')}:${record.minute.toString().padLeft(2, '0')}:${record.second.toString().padLeft(2, '0')}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}