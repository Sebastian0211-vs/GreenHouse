import 'package:flutter/material.dart';

import 'pages/home.dart';
import 'pages/my_tasks.dart';
import 'pages/all_tasks.dart';
import 'pages/inventory.dart';
import 'pages/analytics.dart';
import 'pages/parcelles.dart';
import 'services/auth_service.dart';
import 'pages/login.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenHouse',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/app': (_) => const MainShell(title: 'GreenHouse'),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.title});
  final String title;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    MyTasksPage(),
    AllTasksPage(),
    ParcellesPage(),
    InventoryPage(),
    AnalyticsPage(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _goToPage(int index) {
    Navigator.of(context).pop(); // close drawer
    setState(() => _selectedIndex = index);
  }

  void _disconnect() {
    AuthService.instance.logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void initState() {
    super.initState();

    // Guard: if opened without login, go back to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.instance.currentUser == null) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = AuthService.instance.currentUser;



    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Row(
          children: [
            Image.asset(
              'lib/assets/images/logo.png',
              height: 32,
            ),
            const SizedBox(width: 12),
            const Text('GreenHouse'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {},
          ),
        ],
      ),

      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: cs.primaryContainer),
                accountName: Text(user?.fullName ?? 'Not connected'),
                accountEmail: Text(
                  user != null ? 'Username: ${user.username}' : 'Please sign in',
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: cs.surface,
                  child: user == null
                      ? Icon(Icons.person_outline, color: cs.primary)
                      : ClipOval(
                          child: Image.network(
                            'https://picsum.photos/seed/${Uri.encodeComponent(user.username)}/200/200',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.person, color: cs.primary),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                          ),
                        ),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.home),
                title: const Text("Home"),
                selected: _selectedIndex == 0,
                onTap: () => _goToPage(0),
              ),
              ListTile(
                leading: const Icon(Icons.task),
                title: const Text("My Tasks"),
                selected: _selectedIndex == 1,
                onTap: () => _goToPage(1),
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text("All Tasks"),
                selected: _selectedIndex == 2,
                onTap: () => _goToPage(2),
              ),
              ListTile(
                leading: const Icon(Icons.agriculture),
                title: const Text("Parcelles"),
                selected: _selectedIndex == 3,
                onTap: () => _goToPage(3),
              ),
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text("Inventory"),
                selected: _selectedIndex == 4,
                onTap: () => _goToPage(4),
              ),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text("Analytics"),
                selected: _selectedIndex == 5,
                onTap: () => _goToPage(5),
              ),

              const Spacer(),
              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text("Disconnect"),
                    onPressed: user == null
                        ? null
                        : () {
                            Navigator.of(context).pop(); // close drawer
                            _disconnect();
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'My Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.agriculture), label: 'Parcelles'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }
}
