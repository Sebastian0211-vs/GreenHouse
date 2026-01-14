import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import '../../services/auth_service.dart';

class MyTasksTableWidget extends StatefulWidget {
  final String tableName;
  final List<String> columns;
  final List<String> hiddenColumns;
  final double? maxHeight;
  final Function? onRefresh; 
  

  const MyTasksTableWidget({
    super.key,
    required this.tableName,
    required this.columns,
    this.hiddenColumns = const ['id','username'],
    this.maxHeight,
    this.onRefresh,
  });

  @override
  MyTasksTableWidgetState createState() => MyTasksTableWidgetState();
}

class MyTasksTableWidgetState extends State<MyTasksTableWidget> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final user = AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _fetchData();
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  Future<void> _fetchData() async {
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
      var userId=user?.id;

      final query = """
      SELECT  t.id,
              tt.name || ' of planting n.' || t.planting_id || ', variety: ' || c.variety AS "Task",
              u.username,
              TO_CHAR(t.start_time, 'DD.MM.YYYY HH24:MI') AS "Start time",
              TO_CHAR(t.end_time, 'DD.MM.YYYY HH24:MI') AS "End time",
              ts.name AS "Status",
              TO_CHAR(t.due, 'DD.MM.YYYY') AS "Due"
        FROM tasks AS t
          JOIN task_types AS tt ON t.type_id = tt.id
          JOIN task_status AS ts ON t.status_id = ts.id
          JOIN plantings AS p ON t.planting_id = p.id
          JOIN crops AS c ON p.crop_id = c.id
          LEFT JOIN users AS u ON t.user_id = u.id
        WHERE t.user_id=$userId
        ORDER BY t.due ASC
      """;
      final results = await connection.query(query);

      setState(() {
        _data = results.map((row) => row.toColumnMap()).toList();
        _isLoading = false;
      });

      await connection.close();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> updateTaskProgression(String query) async {
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
      await connection.query(query);
      await connection.close();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onStartPressed(int taskId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task $taskId started.')),
    );

    final query = '''
      UPDATE tasks
      SET
        start_time = LOCALTIMESTAMP,
        status_id = 3,
        due = GREATEST(due, CURRENT_DATE + 1)
      WHERE
        id = $taskId
    ''';
    updateTaskProgression(query);
    refreshData();
  }
  void _onEndPressed(int taskId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task $taskId ended')),
    );
    final query = '''
      WITH update_task AS(
        UPDATE tasks
        SET
          end_time = LOCALTIMESTAMP,
          due = GREATEST(due, CURRENT_DATE + 1),
          status_id = 5
        WHERE
          id = $taskId
        RETURNING id
      )
      -- Then INSERT new stock line
      INSERT INTO stocks(
        item_id,
        stock_movement
      )
      SELECT
        i.id,
        -tm.qty
      FROM
        items AS i
      JOIN
        task_materials AS tm ON tm.item_id = i.id
      JOIN
        update_task AS ut ON tm.task_id = ut.id
    ''';
    updateTaskProgression(query);
    refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Restrict visible columns
    final visibleColumns = widget.columns.where((col) => !widget.hiddenColumns.contains(col)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight ?? constraints.maxHeight,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                ),
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  columns: visibleColumns.map((column) => DataColumn(
                            label: Text(
                              column,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )).toList(),
                  rows: _data.map((rowData) {    
                        var needToStart=false;
                        var needToEnd=false;                        
                        return DataRow(
                          cells: visibleColumns.map((column) {
                            final cellValue = rowData[column]?.toString() ?? '';

                            if (column.toLowerCase() == 'start time' && cellValue.isEmpty) {
                              needToStart=true;
                            }
                            else if (column.toLowerCase() == 'end time' && cellValue.isEmpty) {
                              needToEnd=true;
                            }

                            if (column.toLowerCase() == 'action') {
                              if(needToStart) {
                                return DataCell(
                                  ElevatedButton.icon(
                                    onPressed: () => _onStartPressed(rowData['id']),
                                    icon: const Icon(Icons.play_arrow), // Add the icon here
                                    label: const Text('Start'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(120, 30),
                                    ),
                                  ),
                                );
                              }
                              if(needToEnd) {
                                return DataCell(
                                  ElevatedButton.icon(
                                    onPressed: () => _onEndPressed(rowData['id']),
                                    icon: const Icon(Icons.check), // Add the icon here
                                    label: const Text('End'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(120, 30),
                                    ),
                                  ),
                                );
                              }
                              else {
                                return DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      "Done",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                );
                              }
                            }

                            return DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  cellValue,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
