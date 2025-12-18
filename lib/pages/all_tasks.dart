import 'package:flutter/material.dart';

class AllTasksPage extends StatelessWidget {
  const AllTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
      ),
      body: const Center(
        child: Text('Tasks will appear here'),
      ),
    );
  }
}