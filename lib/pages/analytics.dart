import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:postgres/postgres.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<List<ItemAnalytics>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAnalytics();
  }

  Future<PostgreSQLConnection> _open() async {
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

  Future<List<ItemAnalytics>> _loadAnalytics() async {
    final conn = await _open();
    try {
      // Past stock history
      final history = await conn.query("""
        SELECT
          s.item_id,
          DATE(s.datetime),
          SUM(s.stock_movement)
        FROM stocks s
        GROUP BY s.item_id, DATE(s.datetime)
        ORDER BY DATE(s.datetime)
      """);

      // Current quantities
      final current = await conn.query("""
        WITH stock_qty AS(
          SELECT item_id, SUM(stock_movement) AS qty
          FROM stocks
          GROUP BY item_id
        )
        SELECT i.id, i.name, sq.qty
        FROM items i
        JOIN stock_qty sq ON i.id = sq.item_id
      """);

      // Depletion projection
      final depletion = await conn.query("""
        SELECT
          sq.item_id,
          CURRENT_DATE + ROUND(
            -(sq.qty)
            /
            NULLIF(
              ROUND(
                (
                  SUM(s.stock_movement)
                  /
                  NULLIF(
                    EXTRACT(day FROM (LOCALTIMESTAMP - lr.datetime)),
                    0
                  )
                )::numeric
              ),
              0
            )
          )::integer AS zero_date
        FROM stocks s
        JOIN (
          SELECT item_id, SUM(stock_movement) AS qty
          FROM stocks
          GROUP BY item_id
        ) sq ON s.item_id = sq.item_id
        JOIN (
          SELECT item_id, MAX(datetime) AS datetime
          FROM stocks
          WHERE stock_movement > 0
          GROUP BY item_id
        ) lr ON lr.item_id = s.item_id
        WHERE s.stock_movement < 0
          AND s.datetime > lr.datetime
        GROUP BY sq.item_id, sq.qty, lr.datetime
      """);

      final today = DateTime.now();
      final map = <int, ItemAnalytics>{};

      for (final r in current) {
        map[r[0] as int] = ItemAnalytics(
          id: r[0] as int,
          name: r[1] as String,
          currentQty: (r[2] as num).toDouble(),
          today: today,
        );
      }

      for (final r in history) {
        final id = r[0] as int;
        if (!map.containsKey(id)) continue;
        map[id]!.addPast(r[1] as DateTime, (r[2] as num).toDouble());
      }

      for (final r in depletion) {
        final id = r[0] as int;
        if (!map.containsKey(id)) continue;
        map[id]!.setZeroDate(r[1] as DateTime);
      }

      return map.values.toList();
    } finally {
      await conn.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: FutureBuilder<List<ItemAnalytics>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No analytics data'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (item.zeroDate != null)
                      Text(
                        'Estimated empty on ${item.zeroDateString}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SizedBox(
                        height: 220,
                        child: LineChart(item.chart()),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* -------------------- MODEL -------------------- */

class ItemAnalytics {
  final int id;
  final String name;
  final double currentQty;
  final DateTime today;

  final List<FlSpot> past = [];
  FlSpot? futureEnd;
  DateTime? zeroDate;

  double _running = 0;

  ItemAnalytics({
    required this.id,
    required this.name,
    required this.currentQty,
    required this.today,
  });

  void addPast(DateTime day, double delta) {
    _running += delta;
    final x = day.difference(today).inDays.toDouble();
    past.add(FlSpot(x, _running));
  }

  void setZeroDate(DateTime date) {
    zeroDate = date;
    final x = date.difference(today).inDays.toDouble();
    futureEnd = FlSpot(x, 0);
  }

  String get zeroDateString {
    if (zeroDate == null) return '';
    return '${zeroDate!.day.toString().padLeft(2, '0')}.'
        '${zeroDate!.month.toString().padLeft(2, '0')}.'
        '${zeroDate!.year}';
  }

  LineChartData chart() {
    final minX = past.isEmpty
        ? -5
        : past.map((e) => e.x).reduce((a, b) => a < b ? a : b);
    final maxX = futureEnd?.x ?? 5;

    return LineChartData(
      minX: minX - 2,
      maxX: maxX + 2,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 50,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Colors.grey.withOpacity(0.15),
          strokeWidth: 1,
        ),
      ),
      extraLinesData: ExtraLinesData(
        verticalLines: [
          VerticalLine(
            x: 0,
            color: Colors.grey.withOpacity(0.5),
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              labelResolver: (_) => 'Today',
            ),
          ),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 50,
            reservedSize: 40,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (value, _) {
              if (value == 0) {
                return const Text(
                  'Today',
                  style: TextStyle(fontWeight: FontWeight.bold),
                );
              }
              return Text(value.toInt().toString());
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: past,
          isCurved: false,
          barWidth: 2,
          color: Colors.green.shade700,
          dotData: FlDotData(show: true),
        ),
        if (futureEnd != null)
          LineChartBarData(
            spots: [
              FlSpot(0, currentQty),
              futureEnd!,
            ],
            isCurved: false,
            barWidth: 2,
            color: Colors.red.shade400,
            dashArray: [6, 4],
            dotData: FlDotData(show: false),
          ),
      ],
    );
  }
}
