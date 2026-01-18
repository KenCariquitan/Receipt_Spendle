import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../utils/category_utils.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final byCat = ref.watch(byCategoryProvider);
    final topMerchants = ref.watch(topMerchantsProvider);
    final weekday = ref.watch(weekdaySpendProvider);
    final rolling = ref.watch(rolling30Provider);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F0FF), // soft lavender like inspo
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(summaryProvider);
            ref.invalidate(byCategoryProvider);
            ref.invalidate(topMerchantsProvider);
            ref.invalidate(weekdaySpendProvider);
            ref.invalidate(rolling30Provider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // ---------- TOP SUMMARY CARD ----------
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: summary.when(
                  loading: () => const _SpendleLoading(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (s) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This month at a glance',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _heroStatCard(
                              context,
                              label: 'Total spend',
                              value: _formatCurrency(s.totalSpend),
                              color: scheme.primary,
                              icon: Icons.payments_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _heroStatCard(
                              context,
                              label: 'Receipts',
                              value: s.totalReceipts.toString(),
                              color: scheme.secondary,
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _smallStatChip(
                              icon: Icons.calendar_month_outlined,
                              label: 'Month‑to‑date',
                              value: _formatCurrency(s.monthToDateSpend),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _smallStatChip(
                              icon: Icons.category_outlined,
                              label: 'Top category',
                              value: displayCategory(s.topCategory),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---------- SPENDING BY CATEGORY ----------
              _sectionHeader(
                context,
                title: 'Spending by category',
                icon: Icons.pie_chart_outline,
                trailing: const Icon(Icons.more_horiz, size: 18),
              ),
              const SizedBox(height: 8),
              _sectionCard(
                child: byCat.when(
                  loading: () => const _SpendleLoading(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (rows) {
                    if (rows.isEmpty) return const Text('No data yet.');
                    
                    final colors = [
                      const Color(0xFF7C4DFF),
                      const Color(0xFF00D4AA),
                      const Color(0xFFFF6B6B),
                      const Color(0xFFFFB347),
                      const Color(0xFF4FC3F7),
                      const Color(0xFFBA68C8),
                      const Color(0xFF81C784),
                      const Color(0xFFFFD54F),
                    ];
                    
                    final sections = <PieChartSectionData>[];
                    final total = rows.fold<double>(
                      0.0,
                      (sum, row) => sum + (row['total'] as num).toDouble(),
                    );
                    
                    for (var i = 0; i < rows.length; i++) {
                      final row = rows[i];
                      final value = (row['total'] as num).toDouble();
                      final percentage = total > 0 ? (value / total * 100) : 0.0;
                      sections.add(
                        PieChartSectionData(
                          value: value,
                          color: colors[i % colors.length],
                          radius: 80,
                          title: '${percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          titlePositionPercentageOffset: 0.55,
                        ),
                      );
                    }
                    
                    return Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: sections,
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var i = 0; i < rows.length; i++)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: colors[i % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    displayCategory((rows[i]['category'] ?? 'Unknown') as String),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ---------- TOP MERCHANTS ----------
              _sectionHeader(
                context,
                title: 'Top merchants (this month)',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 8),
              _sectionCard(
                child: topMerchants.when(
                  loading: () => const _SpendleLoading(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Text(
                        'No purchases recorded this month.',
                      );
                    }
                    return Column(
                      children: rows
                          .map(
                            (m) => ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    scheme.primary.withOpacity(0.08),
                                child: Text(
                                  _initialForStore(m.store),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                m.store,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${m.receiptCount} receipt${m.receiptCount == 1 ? '' : 's'}',
                              ),
                              trailing: Text(
                                _formatCurrency(m.totalSpend),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ---------- WEEKDAY SPEND ----------
              _sectionHeader(
                context,
                title: 'Weekday spend',
                icon: Icons.bar_chart_outlined,
              ),
              const SizedBox(height: 8),
              _sectionCard(
                child: weekday.when(
                  loading: () => const _SpendleLoading(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (rows) {
                    if (rows.isEmpty) return const Text('No data yet.');
                    final bars = rows
                        .map(
                          (r) => BarChartGroupData(
                            x: r.weekday,
                            barRods: [
                              BarChartRodData(
                                toY: r.totalSpend,
                                width: 24,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    scheme.secondary.withOpacity(0.95),
                                    scheme.secondary.withOpacity(0.55),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: r.totalSpend * 1.1,
                                  color: Colors.black12,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList();
                    return SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(drawHorizontalLine: true),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    _weekdayLabel(value.toInt()),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          barGroups: bars,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ---------- ROLLING 30-DAY SPEND ----------
              _sectionHeader(
                context,
                title: 'Rolling 30‑day spend',
                icon: Icons.show_chart_outlined,
              ),
              const SizedBox(height: 8),
              _sectionCard(
                child: rolling.when(
                  loading: () => const _SpendleLoading(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (rows) {
                    if (rows.isEmpty) return const Text('No data yet.');
                    final sorted = [...rows]
                      ..sort((a, b) => a.date.compareTo(b.date));
                    final spots = <FlSpot>[];
                    for (var i = 0; i < sorted.length; i++) {
                      spots.add(FlSpot(i.toDouble(), sorted[i].totalSpend));
                    }
                    final maxY = spots.fold<double>(
                      0.0,
                      (prev, e) => e.y > prev ? e.y : prev,
                    );
                    return SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: spots.isNotEmpty ? spots.last.x : 0,
                          minY: 0,
                          maxY: maxY > 0 ? maxY * 1.1 : 1,
                          gridData: const FlGridData(drawHorizontalLine: true),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= sorted.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final d = sorted[idx].date;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      '${d.month}/${d.day}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: scheme.primary,
                              barWidth: 4,
                              shadow: Shadow(
                                color: scheme.primary.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    scheme.primary.withOpacity(0.35),
                                    scheme.primary.withOpacity(0.0),
                                  ],
                                ),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, p, bar, index) =>
                                    FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI HELPERS (NO BACKEND IMPACT) ----------

  Widget _heroStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  static String _formatCurrency(double value) => '₱${value.toStringAsFixed(2)}';

  static String _weekdayLabel(int dow) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (dow >= 0 && dow < names.length) return names[dow];
    return dow == 7 ? 'Sun' : '?';
  }

  static String _initialForStore(String store) {
    final trimmed = store.trim();
    if (trimmed.isEmpty) return '?';
    final chars = trimmed.characters;
    if (chars.isEmpty) {
      return trimmed[0].toUpperCase();
    }
    return chars.first.toUpperCase();
  }
}

/// Simple animated loading with a bouncing coin.
class _SpendleLoading extends StatefulWidget {
  const _SpendleLoading();

  @override
  State<_SpendleLoading> createState() => _SpendleLoadingState();
}

class _SpendleLoadingState extends State<_SpendleLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);
  late final Animation<double> _offset =
      Tween<double>(begin: 0, end: -8).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _offset,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _offset.value),
                child: child,
              );
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.primary.withOpacity(0.6),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.attach_money,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading...',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
