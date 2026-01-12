import 'package:flutter/material.dart';
import 'utils/sql_table_2.dart';

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  _MyTasksPageState createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
 final GlobalKey<MyTasksTableWidgetState> _tableKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
              _tableKey.currentState?.refreshData();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Add any other widgets you need above the table
            const SizedBox(height: 10),
            Expanded(
              child: MyTasksTableWidget(
                key: _tableKey,
                tableName: 'tasks',
                columns: ['id','username','task', 'start_time', 'end_time', 'action', 'status', 'due'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
