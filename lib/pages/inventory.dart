import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:postgres/postgres.dart';

class Item{
  final int id;
  final String name;
  final int supplierId;
  final int? stockQuantity;
  final String unit;
  final DateTime? zeroStockDate;
  final List<StockLine>? stockLines;

  Item({required this.id, required this.name, required this.supplierId, required this.stockQuantity, required this.unit, this.zeroStockDate, this.stockLines});

  factory Item.fromMap(Map<String, dynamic> map) {  
    return Item(
      id: map['id'],
      name: map['name'],
      supplierId: map['supplier_id'],
      stockQuantity: map['qty'],
      unit: map['unit'],
      zeroStockDate: map['zeroStockDate'],
      stockLines: null,
    );
  }

  static Future<Item> fromMapAsync(Map<String, dynamic> map) async {
    final zeroStockDate = await Item.fetchZeroStockDate(map['id']);

    return Item(
      id: map['id'],
      name: map['name'],
      supplierId: map['supplier_id'],
      stockQuantity: map['qty'],
      unit: map['unit'],
      zeroStockDate: zeroStockDate,
      stockLines: null,
    );
  }

  static Future<DateTime?> fetchZeroStockDate(int itemId) async {
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
          WITH stock_qty AS(
              SELECT
                s.item_id,
                SUM(s.stock_movement) AS qty
              FROM
                stocks AS s
              GROUP BY
                s.item_id
          ),
          item_qty AS(
            SELECT
              i.name,
              sq.qty,
              u.unit
            FROM
              items AS i
            JOIN
              units AS u ON i.unit_id = u.id
            JOIN
              stock_qty AS sq ON i.id = sq.item_id
            WHERE
              sq.item_id = @itemId
          ),
          last_resupply AS(
            SELECT
              s.datetime
            FROM
              stocks AS s
            WHERE
              s.item_id = @itemId AND
              s.stock_movement > 0
            ORDER BY
              s.datetime DESC
            LIMIT
              1
          )
          SELECT
            CURRENT_DATE + ROUND(
              -(SELECT q.qty FROM item_qty AS q)
              /
              NULLIF(
                ROUND(
                  (
                    SUM(s.stock_movement)
                    /
                    NULLIF(
                      EXTRACT(
                        day FROM (LOCALTIMESTAMP - (SELECT datetime FROM last_resupply))
                      ),
                      0
                    )
                  )::numeric
                ),
                0
              )
            )::integer AS zero_date
          FROM
            stocks AS s
          WHERE
            s.item_id = @itemId AND
            s.stock_movement < 0 AND
            s.datetime > (SELECT lr.datetime FROM last_resupply AS lr)
        ''',
        substitutionValues: {
          'itemId': itemId,
        },
      );

      await connection.close();

      if (results.isNotEmpty && results.first[0] != null) {
        return results.first[0] as DateTime;
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching zero stock date for item $itemId: $e');
      return null;
    }
  }
}

class StockLine{
  final int id;
  final int itemId;
  final double stockMovement;
  final DateTime date;

  StockLine({required this.id, required this.itemId, required this.stockMovement, required this.date});
  factory StockLine.fromMap(Map<String, dynamic> map) {
    return StockLine(
      id: map['id'],
      itemId: map['item_id'],
      stockMovement: map['stock_movement'],
      date: map['date'],
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<Item> _items = [];
  final user = AuthService.instance.currentUser;


  Future<void> _loadItems() async {
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
        WITH stock_qty AS(
          SELECT
            s.item_id,
            SUM(s.stock_movement) AS qty
          FROM
            stocks AS s
          GROUP BY
            s.item_id
        )
        SELECT
          i.id,
          i.name,
          i.supplier_id,
          sq.qty,
          u.unit
        FROM
          items AS i
        JOIN
          units AS u ON i.unit_id = u.id
        JOIN
          stock_qty AS sq ON i.id = sq.item_id
        ''',
      );
      final futures = results.map((row) {
        final map = <String, dynamic>{
          'id': row[0],
          'name': row[1],
          'supplier_id': row[2],
          'qty': row[3],
          'unit': row[4],
        };
        print(  "name: ${map['name']} - qty: ${map['qty']} ${map['unit']}");
        return Item.fromMapAsync(map);
      }).toList();

      await connection.close();

      final items = await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        _items = items;
      });

    } catch (e) {
      print('Error loading items: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
          actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () async {
              _loadItems();
            },
          ),
        ],
        ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Inventory")),
                ],
                rows: _items!.map((item) {
                  final now = DateTime.now();

                  final isSoon = item.zeroStockDate != null &&
                      item.zeroStockDate!
                          .difference(now)
                          .inDays <= 7;

                  return DataRow(
                    color: isSoon
                        ? WidgetStateProperty.all(
                            Colors.orange.withValues(),
                          )
                        : null,

                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 🔹 First line
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  "${item.stockQuantity ?? "-"} ${item.unit}",
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // 🔹 Second line
                            if (item.zeroStockDate != null)
                              Text(
                                "Out of stock on: ${item.zeroStockDate!.toLocal().toString().split(' ')[0]}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color.fromARGB(255, 73, 73, 73),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

