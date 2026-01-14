import 'package:flutter/material.dart';
import 'utils/sql_table.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key});

  @override
  _AllTasksPageState createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
 final GlobalKey<AllTasksTableWidgetState> _tableKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
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
              child: AllTasksTableWidget(
                key: _tableKey,
                tableName: 'tasks',
                columns: ['id','Task', 'Username', 'Status', 'Due'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
