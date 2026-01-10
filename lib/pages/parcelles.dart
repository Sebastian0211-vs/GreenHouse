import 'package:flutter/material.dart';
import 'utils/sql_parcelles.dart';
import 'dart:math';
import '../../services/auth_service.dart';
import 'package:postgres/postgres.dart';

/* class ParcellesPage extends StatefulWidget {
  const ParcellesPage({super.key});

  @override
  State<ParcellesPage> createState() => _ParcellesPageState();
}

class _ParcellesPageState extends State<ParcellesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcelles'),
      ),
      body: Center(
        child: Text('Parcelles Page'),
      ),
    );
  }
} */

class Bed {
  final int id;
  final int size;
  final List<Planting> plants;

  Bed({
    required this.id,
    required this.size,
    required this.plants,
  });

  static Future<Bed> fromDbRow(
    Map<String, dynamic> row,
    PostgreSQLConnection connection,
  ) async {
    try {
      final bedId = row['id'] as int;
      print("Loading plantings for bed $bedId");

      final plantResults = await connection.query(
        '''
        SELECT
          p.id,
          p.bed_id,
          p.crop_id,
          c.variety AS name,
          p.planting_date,
          p.size
        FROM
          plantings AS p
        JOIN
          crops AS c ON c.id = p.crop_id
        WHERE
          p.bed_id = @bedId
        ''',
        substitutionValues: {
          'bedId': bedId,
        },
      );

      final plants = plantResults.map((p) {
        final map = p.toColumnMap();
        return Planting.fromRow(map);
      }).toList();

      return Bed(
        id: bedId,
        size: row['size'] as int,
        plants: plants,
      );
    } catch (e) {
      throw Exception('Error fetching plantings for bed: $e');
    }
  }
}

class Planting {
  final int id;
  final int bedId;
  final int cropId;
  final String name;
  final DateTime plantingDate;
  final int size;

  Planting({
    required this.id,
    required this.bedId,
    required this.cropId,
    required this.name,
    required this.plantingDate,
    required this.size,
  });

  factory Planting.fromRow(Map<String, dynamic> row) {
    return Planting(
      id: row['id'] as int,
      bedId: row['bed_id'] as int,
      cropId: row['crop_id'] as int,
      name: row['name'] as String,
      plantingDate: row['planting_date'] as DateTime,
      size: row['size'] as int,
    );
  }
}

class BedTile {
  final String label;
  final Color color;
  final String tooltip;

  BedTile(this.label, this.color, this.tooltip);
}

class ParcellesPage extends StatefulWidget {
  const ParcellesPage({super.key});

  @override
  State<ParcellesPage> createState() => _ParcellesPageState();
}

class _ParcellesPageState extends State<ParcellesPage> { 
  List<Bed> _beds = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final user = AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadBeds();
  }

  Future<List<Bed>> _getBeds() async {
    try {
      final connection = PostgreSQLConnection(
        'pg-crophouse-crophouse.d.aivencloud.com',
        12357,
        'crophouse',
        username: 'avnadmin',
        password: 'AVNS_yZ3iY6b_woJDTC5hQTW',
        useSSL: true,
      );

      await connection.open();

      const query = "SELECT id, size FROM beds";
      final results = await connection.query(query);

      final futures = results.map((row) {
        final map = row.toColumnMap();
        print(  "Loading bed ${map['id']} of size ${map['size']}");
        return Bed.fromDbRow(map, connection);
      }).toList();

      final beds = await Future.wait(futures); 

      await connection.close();
      return beds;
    } catch (e) {
        throw Exception('Error fetching beds: $e');
    }
  }

  Future<void> _loadBeds() async {
    try {
      final beds = await _getBeds();
      setState(() {
        _beds = beds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      throw Exception('Error loading beds: $e');
    }
  }

  /// Generate one random nice color
  Color randomColor() {
    final Random random = Random();

    // pick hue 0..360, saturation 0.5..1, lightness 0.4..0.8
    final h = random.nextDouble() * 360;
    final s = 0.5 + random.nextDouble() * 0.5; // 0.5 - 1
    final l = 0.4 + random.nextDouble() * 0.4; // 0.4 - 0.8

    return HSLColor.fromAHSL(1.0, h, s, l).toColor();
  }

  /// Generate a stack (list) of random colors
  List<Color> randomColorStack(int length) {
    return List.generate(length, (_) => randomColor());
  }

  List<BedTile> buildTiles({required int bedSize, required List<Planting> plantings}) {
    final tiles = <BedTile>[];
    int used = 0;
    final colorStack = randomColorStack(plantings.length);

    for (final planting in plantings) {
      final color = colorStack.removeLast();
      for (int i = 0; i < planting.size; i++) {
        tiles.add(BedTile(planting.id.toString(), color, planting.name));
        used++;
      }
    }

    final remaining = bedSize - used;
    for (int i = 0; i < remaining; i++) {
      tiles.add(BedTile("Empty", Colors.grey.shade300, "Empty"));
    }

    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Parcelles")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _beds.length,
        itemBuilder: (context, bedIndex) {
          final bed = _beds[bedIndex];
          final tiles = buildTiles(bedSize: bed.size, plantings: bed.plants);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bed #${bedIndex + 1}",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, tileIndex) {
                  final tile = tiles[tileIndex];
                  return Tooltip(
                    message: tile.tooltip,   // 👈 plant name here
                    child: Container(
                      decoration: BoxDecoration(
                        color: tile.color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Center(
                        child: Text(
                          tile.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis, // 👈 avoids ugly overflow
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24), // space between beds
            ],
          );
        },
      ),
    );
  }
}
