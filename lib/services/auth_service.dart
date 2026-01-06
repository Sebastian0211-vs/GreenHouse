import 'package:postgres/postgres.dart';

class AuthUser {
  final int id;
  final String username;
  final String firstName;
  final String lastName;

  AuthUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
  });

  String get fullName => '$firstName $lastName';
}

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  AuthUser? currentUser;

  Future<PostgreSQLConnection> _openConn() async {
    final conn = PostgreSQLConnection(
      'pg-crophouse-crophouse.d.aivencloud.com',
      12357,
      'crophouse',
      username: 'avnadmin',
      password: 'AVNS_yZ3iY6b_woJDTC5hQTW',
      useSSL: true,
    );
    await conn.open();
    return conn;
  }

  Future<AuthUser?> login(String username, String pwd) async {
    final conn = await _openConn();
    try {
      final res = await conn.query(
        '''
        SELECT id, username, first_name, last_name
        FROM users
        WHERE username = @u
          AND pwd = @p
        LIMIT 1
        ''',
        substitutionValues: {
          'u': username,
          'p': pwd,
        },
      );

      if (res.isEmpty) return null;

      final r = res.first;
      currentUser = AuthUser(
        id: r[0] as int,
        username: r[1] as String,
        firstName: r[2] as String,
        lastName: r[3] as String,
      );

      return currentUser;
    } finally {
      await conn.close();
    }
  }

  void logout() {
    currentUser = null;
  }

  bool get isLoggedIn => currentUser != null;
}
