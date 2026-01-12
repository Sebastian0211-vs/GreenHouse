import 'package:flutter/material.dart';
import 'utils/sql_parcelles.dart';
import 'dart:math';
import '../../services/auth_service.dart';
import 'package:postgres/postgres.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;



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

      final plantResults = await connection.query(
        '''
        SELECT
          p.id,
          p.bed_id,
          p.crop_id,
          c.variety AS name,
          p.planting_date,
          p.harvesting_date,
          p.is_trial,
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

      final futures = plantResults.map((p) {
        final map = p.toColumnMap();
        return Planting.fromRow(map, connection);
      }).toList();

      final plants = await Future.wait(futures);

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

class Note {
  final int id;
  final int plantingId;
  final DateTime createdAt;
  final String content;

  Note({
    required this.id,
    required this.plantingId,
    required this.createdAt,
    required this.content,
  });

  factory Note.fromRow(Map<String, dynamic> row) {
    return Note(
      id: row['id'] as int,
      plantingId: row['planting_id'] as int,
      createdAt: row['created_at'] as DateTime,
      content: row['content'] as String,
    );
  }

  static Future<List<Note>> fetchNotesForPlanting(int plantingId) async {
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
      final noteResults = await connection.query(
        '''
        SELECT
          n.id,
          n.planting_id,
          n.text,
          n.datetime AS created_at
        FROM
          notes AS n
        WHERE
          n.planting_id = @plantingId
        ''',
        substitutionValues: {
          'plantingId': plantingId,
        },
      );

      await connection.close();

      final notes = noteResults.map((n) {
        final map = n.toColumnMap();
        return Note(
          id: map['id'] as int,
          plantingId: map['planting_id'] as int,
          content: map['text'] as String,
          createdAt: map['created_at'] as DateTime,
        );
      }).toList();
      return notes;
    } catch (e) {
      throw Exception('Error fetching notes for planting $plantingId: $e');
    }
  }

  static Future<void> insertNote(int plantingId, String text, PostgreSQLConnection connection) async {
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
      await connection.query(
        '''
        INSERT INTO notes (planting_id, text)
        VALUES (@plantingId, @text)
        ''',
        substitutionValues: {
          'plantingId': plantingId,
          'text': text,
        },
      );

      await connection.close();
    } catch (e) {
      throw Exception('Error inserting new note for planting $plantingId: $e');
    }
  }
}

class Task {
  final int id;
  final String? username;
  final String task;
  final String status;
  final DateTime dueDate;
  final int bedId;

  Task({
    required this.id,
    required this.username,
    required this.task,
    required this.status,
    required this.dueDate,
    required this.bedId,
  });

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'] as int,
      username: row['username'] as String?,
      task: row['task'] as String,
      status: row['status'] as String,
      dueDate: row['due_date'] as DateTime,
      bedId: row['bed_id'] as int,
    );
  }

  static Future<List<Task>> fetchTasksForPlanting(int plantingId) async {
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
      final taskResults = await connection.query(
        '''
        SELECT
          t.id,
          u.username, 
          tt.name || ' of planting n.' || t.planting_id || ', variety: ' || c.variety AS task,
          ts.name AS status, 
          t.due AS due_date,
          p.bed_id
        FROM
          tasks AS t
        JOIN
          task_types AS tt ON t.type_id = tt.id
        JOIN
          task_status AS ts ON t.status_id = ts.id
        JOIN
          plantings AS p ON t.planting_id = p.id
        JOIN
          crops AS c ON p.crop_id = c.id
        LEFT JOIN
          users AS u ON t.user_id = u.id
        WHERE
          t.planting_id = @plantingId AND
          t.due <= CURRENT_DATE + INTERVAL '3 day'
          AND t.status_id <> 5
        ORDER BY t.due 
        ''',
        substitutionValues: {
          'plantingId': plantingId,
        },
      );

      await connection.close();

      final tasks = taskResults.map((t) {
        final map = t.toColumnMap();
        return Task.fromRow(map);
      }).toList();
      return tasks;
    } catch (e) {
      throw Exception('Error fetching tasks for planting $plantingId: $e');
    }
  }

  static Future<void> insertTask(int plantingId, int typeId, DateTime dueDate) async {
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
      await connection.query(
        '''
        INSERT INTO tasks (type_id, planting_id, status_id, due)
        VALUES (@typeId, @plantingId, @statusId, @dueDate)
        ''',
        substitutionValues: {
          'typeId': typeId,
          'plantingId': plantingId,
          'statusId': 1,
          'dueDate': dueDate,
        },
      );

      await connection.close();
    } catch (e) {
      throw Exception('Error inserting new task for planting $plantingId: $e');
    }
  }
}

class TaskType {
  final int id;
  final String name;

  TaskType({
    required this.id,
    required this.name,
  });

  factory TaskType.fromRow(Map<String, dynamic> row) {
    return TaskType(
      id: row['id'] as int,
      name: row['name'] as String,
    );
  }

  static Future<List<TaskType>> fetchTaskTypes() async {
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
      final results = await connection.query(
        '''
        SELECT id, name
        FROM task_types
        ORDER BY id
        '''
      );

      await connection.close();

      return results.map((r) {
        final map = r.toColumnMap();
        return TaskType.fromRow(map);
      }).toList();
    }catch (e) {
      throw Exception('Error fetching task statuses: $e');
    }
  }
}

class Planting {
  final int id;
  final int bedId;
  final int cropId;
  final String name;
  final DateTime plantingDate;
  final DateTime harvestingDate;
  final bool isTrial;
  final int size;
  List<Note>? notes;
  List<Task>? tasks;

  Planting({
    required this.id,
    required this.bedId,
    required this.cropId,
    required this.name,
    required this.plantingDate,
    required this.harvestingDate,
    required this.isTrial,
    required this.size,
    required this.notes,
    required this.tasks,
  });

  static Future<Planting> fromRow(
    Map<String, dynamic> row,
    PostgreSQLConnection connection,
  ) async {
    try {
      return Planting(
        id: row['id'] as int,
        bedId: row['bed_id'] as int,
        cropId: row['crop_id'] as int,
        name: row['name'] as String,
        plantingDate: row['planting_date'] as DateTime,
        harvestingDate: row['harvesting_date'] as DateTime,
        isTrial: row['is_trial'] as bool,
        size: row['size'] as int,
        notes: null,
        tasks: null,
      );
    } catch (e) {
      throw Exception('Error fetching notes for planting: $e');
    }
  }
}

class BedTile {
  final String label;
  final Color color;
  final String tooltip;
  final Planting planting;

  BedTile(this.label, this.color, this.tooltip, this.planting);
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
  final Map<String, String?> _wikiThumbCache = {}; // plantName -> url or null
  final Map<String, Future<String?>> _wikiThumbInFlight = {}; // avoids duplicate requests

  final user = AuthService.instance.currentUser;
  
  final connection = PostgreSQLConnection(
    'pg-crophouse-crophouse.d.aivencloud.com',
    12357,
    'crophouse',
    username: 'avnadmin',
    password: 'AVNS_yZ3iY6b_woJDTC5hQTW',
    useSSL: true,
  );

  @override
  void initState() {
    super.initState();
    _loadBeds();
  }

  Future<List<Bed>> _getBeds(PostgreSQLConnection connection) async {
    try {
      await connection.open();

      const query = "SELECT id, size FROM beds";
      final results = await connection.query(query);

      final futures = results.map((row) {
        final map = row.toColumnMap();
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
      final beds = await _getBeds(connection);
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


Future<String?> _fetchWikiThumbFromDomain({
  required String domain,
  required String title,
}) async {
  final uri = Uri.https(domain, '/w/api.php', {
    'action': 'query',
    'format': 'json',
    'prop': 'pageimages',
    'titles': title,
    'pithumbsize': '500',
    'pilicense': 'any',
    'redirects': '1',
    'origin': '*', // important for web
  });

  final resp = await http.get(uri);
  if (resp.statusCode != 200) return null;

  final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
  final pages = (jsonMap['query']?['pages']) as Map<String, dynamic>?;
  if (pages == null || pages.isEmpty) return null;

  final firstPage = pages.values.first as Map<String, dynamic>;
  final thumb = firstPage['thumbnail'] as Map<String, dynamic>?;
  return thumb?['source'] as String?;
}

Future<String?> _searchAndFetchWikiThumb({
  required String domain,
  required String query,
}) async {
  // Uses Wikipedia search to find the best page title, then fetch thumbnail
  final searchUri = Uri.https(domain, '/w/api.php', {
    'action': 'query',
    'format': 'json',
    'list': 'search',
    'srsearch': query,
    'srlimit': '1',
    'origin': '*',
  });

  final resp = await http.get(searchUri);
  if (resp.statusCode != 200) return null;

  final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
  final search = (jsonMap['query']?['search']) as List<dynamic>?;
  if (search == null || search.isEmpty) return null;

  final first = search.first as Map<String, dynamic>;
  final title = first['title'] as String?;
  if (title == null || title.isEmpty) return null;

  return _fetchWikiThumbFromDomain(domain: domain, title: title);
}


Future<String?> _getWikipediaThumb(String plantName) async {
  final name = plantName.trim();
  if (name.isEmpty || name == "Empty") return null;

  if (_wikiThumbCache.containsKey(name)) return _wikiThumbCache[name];
  if (_wikiThumbInFlight.containsKey(name)) return _wikiThumbInFlight[name]!;

  String cleanup(String s) {
    // crude but effective: remove cultivar-ish qualifiers
    // keep main noun (e.g., "Carotte Purple Haze" -> "Carotte")
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length <= 1) return s;
    // If it contains "Purple", "Haze", etc. drop everything after first word
    // If you want smarter later, we can map crop_id -> canonical wiki title in DB.
    return parts.first;
  }

  final future = () async {
    try {
      // 1) Try exact title on French Wikipedia
      var url = await _fetchWikiThumbFromDomain(domain: 'fr.wikipedia.org', title: name);

      // 2) Try exact title on English Wikipedia
      url ??= await _fetchWikiThumbFromDomain(domain: 'en.wikipedia.org', title: name);

      // 3) Search on FR
      url ??= await _searchAndFetchWikiThumb(domain: 'fr.wikipedia.org', query: name);

      // 4) Search on EN
      url ??= await _searchAndFetchWikiThumb(domain: 'en.wikipedia.org', query: name);

      // 5) Cleanup fallback (species/common name)
      final cleaned = cleanup(name);
      if (url == null && cleaned != name) {
        url ??= await _searchAndFetchWikiThumb(domain: 'fr.wikipedia.org', query: cleaned);
        url ??= await _searchAndFetchWikiThumb(domain: 'en.wikipedia.org', query: cleaned);
      }

      _wikiThumbCache[name] = url;
      return url;
    } catch (_) {
      _wikiThumbCache[name] = null;
      return null;
    } finally {
      _wikiThumbInFlight.remove(name);
    }
  }();

  _wikiThumbInFlight[name] = future;
  return future;
}




  Color randomColor() {
    final Random random = Random();

    // pick hue 0..360, saturation 0.5..1, lightness 0.4..0.8
    final h = random.nextDouble() * 360;
    final s = 0.5 + random.nextDouble() * 0.5; // 0.5 - 1
    final l = 0.4 + random.nextDouble() * 0.4; // 0.4 - 0.8

    return HSLColor.fromAHSL(1.0, h, s, l).toColor();
  }

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
        tiles.add(BedTile(planting.id.toString(), color, planting.name, planting));
        used++;
      }
    }

    final remaining = bedSize - used;
    for (int i = 0; i < remaining; i++) {
      tiles.add(BedTile("Empty", Colors.grey.shade300, "Empty", Planting(id: 0, bedId: 0, cropId: 0, name: "Empty", plantingDate: DateTime.now(), harvestingDate: DateTime.now(), isTrial: false, size: 0, notes: [], tasks: [])));
    }

    return tiles;
  }

  void _openAddNoteModal(
    BuildContext context,
    Planting planting,
    void Function(void Function()) refreshParent,
  ) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add Note",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Write something smart 🌿",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                child: const Text("Save"),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;

                  await Note.insertNote(planting.id, text, connection);

                  // Reload notes
                  planting.notes = null;

                  Navigator.pop(context); // close add modal
                  refreshParent(() {});   // refresh notes modal
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openNotesModal(BuildContext context, Planting planting) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {

      bool isLoading = false;
      bool hasTriggeredLoad = false;

      return StatefulBuilder(
        builder: (context, setModalState) {

          Future<void> loadNotes() async {
            if (planting.notes != null || isLoading) return;

            setModalState(() {
              isLoading = true;
            });

            final notes = await Note.fetchNotesForPlanting(
              planting.id,
            );

            setModalState(() {
              planting.notes = notes;
              isLoading = false;
            });
          }

          // 👇 Run ONCE after first frame
          if (!hasTriggeredLoad) {
            hasTriggeredLoad = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadNotes();
            });
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "🌱 Notes for ${planting.name}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                if (planting.notes == null || isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else if (planting.notes!.isEmpty)
                  const Text("No notes yet 🌱")
                else
                  ...planting.notes!.map(
                    (note) =>  Card(
                      child: ListTile(
                        title: Text(note.content),
                        subtitle: Text(
                          note.createdAt.toLocal().toIso8601String().split('T').first,
                        ),
                      ),
                    ),
                  ).toList(),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add note"),
                  onPressed: () {
                    _openAddNoteModal(context, planting, setModalState);
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  void _openAddTaskModal(
    BuildContext context,
    Planting planting,
    void Function(void Function()) refreshParent,
  ) {
    final taskController = TextEditingController();
    DateTime? selectedDueDate;

    // --- modal state variables ---
    List<TaskType>? statuses;
    TaskType? selectedStatus;
    bool hasLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Lazy-load statuses once
            if (!hasLoaded) {
              hasLoaded = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final data = await TaskType.fetchTaskTypes();
                  if (!context.mounted) return; // ⚡ safety check
                  setModalState(() {
                    statuses = data;
                    selectedStatus = data.first;
                  });
                } catch (e) {
                  print("Error fetching task statuses: $e");
                }
              });
            }

            Future<void> pickDueDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) setModalState(() => selectedDueDate = picked);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Add Task",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDueDate == null
                              ? "No due date selected"
                              : "Due: ${selectedDueDate!.toLocal().toString().split(' ')[0]}",
                        ),
                      ),
                      ElevatedButton(
                        child: const Text("Pick date"),
                        onPressed: pickDueDate,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (statuses == null)
                    const CircularProgressIndicator()
                  else
                    DropdownButton<TaskType>(
                      isExpanded: true,
                      value: selectedStatus,
                      items: statuses!.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() => selectedStatus = value);
                      },
                    ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    child: const Text("Create"),
                    onPressed: () async {
                      final text = taskController.text.trim();
                      if (text.isEmpty || selectedStatus == null || selectedDueDate == null) return;

                      await Task.insertTask(
                        planting.id,
                        selectedStatus!.id,
                        selectedDueDate!,
                      );

                      planting.tasks = null; // force reload

                      if (context.mounted) {
                        Navigator.pop(context);
                        refreshParent(() {}); // update parent grid/list
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _openTasksModal(BuildContext context, Planting planting) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {

          Future<void> loadTasks() async {
            if (planting.tasks != null) return;

            final tasks = await Task.fetchTasksForPlanting(
              planting.id,
            );

            setModalState(() {
              planting.tasks = tasks;
            });
          }

          loadTasks();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "📝 Tasks for ${planting.name}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                if (planting.tasks == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else if (planting.tasks!.isEmpty)
                  const Text("No tasks yet 💤")
                else
                  ...planting.tasks!.map((task) => Card(
                        child: ListTile(
                          title: Text(task.task),
                          subtitle: Text(
                            "Status: ${task.status}\n"
                            "Due: ${task.dueDate.toLocal().toIso8601String().split('T').first}\n"
                            "Assigned: ${task.username ?? "Unassigned"}",
                          ),
                        ),
                      )),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add task"),
                  onPressed: () {
                    _openAddTaskModal(context, planting, setModalState);
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
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

                  return InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tile.tooltip,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text("Crop size: ${tile.planting.size}"),
                                Text(
                                  "Planted on: ${tile.planting.plantingDate.toLocal().toIso8601String().split('T').first}",
                                ),
                                Text(
                                  "Planned harvest: ${tile.planting.harvestingDate.toLocal().toIso8601String().split('T').first}",
                                ),
                                Text("Trial: ${tile.planting.isTrial}"),
                                const SizedBox(height: 16),

                                ElevatedButton.icon(
                                  icon: const Icon(Icons.note),
                                  label: const Text("See notes"),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openNotesModal(context, tile.planting);
                                  },
                                ),

                                ElevatedButton.icon(
                                  icon: const Icon(Icons.task),
                                  label: const Text("See tasks"),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openTasksModal(context, tile.planting);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },

                    child: Tooltip(
  message: tile.tooltip,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Always have a fallback
        Container(
          decoration: BoxDecoration(
            color: tile.color,
            border: Border.all(color: Colors.black12),
          ),
        ),

        // Wikipedia background image (async)
        if (tile.planting.id != 0 && tile.planting.name != "Empty")
          FutureBuilder<String?>(
  future: _getWikipediaThumb(tile.planting.name),
  builder: (context, snap) {
    final url = snap.data;

    // DEBUG: show state
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (url == null) {
      // No result: show nothing (keeps tile color), but during dev you can show an icon:
      // return const Center(child: Icon(Icons.image_not_supported));
      return const SizedBox.shrink();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, e, __) {
        // DEBUG
        debugPrint('Wiki image failed for ${tile.planting.name}: $e');
        return const SizedBox.shrink();
      },
    );
  },
),


        // Dark overlay for readability (only if we potentially have an image)
        if (tile.planting.id != 0 && tile.planting.name != "Empty")
          Container(color: Colors.black.withOpacity(0.35)),

        Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              tile.tooltip,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 6,
                    color: Colors.black54,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
