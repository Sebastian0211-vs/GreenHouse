import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

class AllTasksTableWidget extends StatefulWidget {
  final String tableName;
  final List<String> columns;
  final List<String> hiddenColumns;
  final double? maxHeight;
  final Function? onRefresh; 

  const AllTasksTableWidget({
    Key? key,
    required this.tableName,
    required this.columns,
    this.hiddenColumns = const ['id'],
    this.maxHeight,
    this.onRefresh,
  }) : super(key: key);

  @override
  AllTasksTableWidgetState createState() => AllTasksTableWidgetState();
}

class AllTasksTableWidgetState extends State<AllTasksTableWidget> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  String _errorMessage = '';

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
        password: '', // don't forget to input password
        useSSL: true,
      );

      await connection.open();

      final query = """
      SELECT  t.id,
              tt.name || ' of planting n.' || t.planting_id || ', variety: ' || c.variety AS Task,
              u.username,
              ts.name AS Status,
              TO_CHAR(t.due, 'DD.MM.YYYY') AS Due
        FROM tasks AS t
          JOIN task_types AS tt ON t.type_id = tt.id
          JOIN task_status AS ts ON t.status_id = ts.id
          JOIN plantings AS p ON t.planting_id = p.id
          JOIN crops AS c ON p.crop_id = c.id
          LEFT JOIN users AS u ON t.user_id = u.id
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

  void _onEmptyUsernamePressed(int taskId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Button pressed for taskId $taskId')),
    );

    // You can add your logic here to update the username
    // For example, show a dialog to edit the username
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
                        return DataRow(
                          cells: visibleColumns.map((column) {
                            final cellValue = rowData[column]?.toString() ?? '';

                            if (column.toLowerCase() == 'username' && cellValue.isEmpty) {
                              return DataCell(
                                ElevatedButton(
                                  onPressed: () => _onEmptyUsernamePressed(rowData['id']),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: const Size(120, 30),
                                  ),
                                  child: const Text('Assign Task'),
                                ),
                              );
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
