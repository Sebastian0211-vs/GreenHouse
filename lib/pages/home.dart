import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = loadDashboard();
  }

  Future<PostgreSQLConnection> _openConnection() async {
    final c = PostgreSQLConnection(
      'pg-crophouse-crophouse.d.aivencloud.com',
      12357,
      'crophouse',
      username: 'avnadmin',
      password: 'AVNS_yZ3iY6b_woJDTC5hQTW',
      useSSL: true,
    );
    await c.open();
    return c;
  }

  Future<DashboardData> loadDashboard() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return DashboardData.empty();
    }

    final conn = await _openConnection();
    try {
      final dueToday = await conn.query(
        "SELECT COUNT(*) FROM tasks WHERE user_id = ${user.id} AND due = CURRENT_DATE",
      );

      final dueSoon = await conn.query(
        "SELECT COUNT(*) FROM tasks WHERE user_id = ${user.id} AND due <= CURRENT_DATE + 7",
      );

      final nextTasks = await conn.query("""
        SELECT tt.name, TO_CHAR(due, 'DD.MM.YYYY')
        FROM tasks t
        JOIN task_types tt ON t.type_id = tt.id
        WHERE t.user_id = ${user.id}
        ORDER BY due
        LIMIT 3
      """);

      final lowStock = await conn.query("""
        SELECT i.name, COALESCE(SUM(s.stock_movement),0)
        FROM items i
        LEFT JOIN stocks s ON s.item_id = i.id
        GROUP BY i.name
        HAVING COALESCE(SUM(s.stock_movement),0) <= 5
        ORDER BY 2
        LIMIT 3
      """);

      return DashboardData(
        username: user.username,
        dueToday: dueToday.first[0] as int,
        dueSoon: dueSoon.first[0] as int,
        nextTasks: nextTasks
            .map((r) => '${r[0]} – ${r[1]}')
            .toList(),
        lowStock: lowStock
            .map((r) => '${r[0]} (${r[1]})')
            .toList(),
      );
    } finally {
      await conn.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _future = loadDashboard();
            }),
          )
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final d = snap.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = loadDashboard());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hello ${d.username}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('Tasks due today'),
                  trailing: Text('${d.dueToday}'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Tasks due in 7 days'),
                  trailing: Text('${d.dueSoon}'),
                ),

                const Divider(height: 32),

                const Text('Next tasks'),
                ...d.nextTasks.map((t) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.chevron_right),
                      title: Text(t),
                    )),

                const Divider(height: 32),

                const Text('Low stock'),
                ...d.lowStock.map((s) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning),
                      title: Text(s),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* -------------------- Model -------------------- */

class DashboardData {
  final String username;
  final int dueToday;
  final int dueSoon;
  final List<String> nextTasks;
  final List<String> lowStock;

  DashboardData({
    required this.username,
    required this.dueToday,
    required this.dueSoon,
    required this.nextTasks,
    required this.lowStock,
  });

  factory DashboardData.empty() => DashboardData(
        username: 'User',
        dueToday: 0,
        dueSoon: 0,
        nextTasks: const [],
        lowStock: const [],
      );
}
