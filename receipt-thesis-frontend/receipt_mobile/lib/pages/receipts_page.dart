import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models.dart';
import 'receipt_detail_page.dart';
import '../utils/category_utils.dart';

class ReceiptsPage extends ConsumerStatefulWidget {
  const ReceiptsPage({super.key});

  @override
  ConsumerState<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends ConsumerState<ReceiptsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _categoryFilter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _categoryFilter = null;
      _dateRange = null;
    });
  }

  List<Receipt> _applyFilters(List<Receipt> list) {
    return list.where((r) {
      final storeText = (r.store ?? r.storeNormalized ?? '').toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty || storeText.contains(_searchQuery);

      final categoryValue = r.category?.trim();
      final matchesCategory = _categoryFilter == null ||
          _categoryFilter == 'All' ||
          (_categoryFilter != null &&
              categoryValue != null &&
              categoryValue == _categoryFilter);

      bool matchesDate = true;
      if (_dateRange != null) {
        final parsed = r.date != null ? DateTime.tryParse(r.date!) : null;
        matchesDate = parsed != null &&
            !parsed.isBefore(_dateRange!.start) &&
            !parsed.isAfter(_dateRange!.end);
      }

      return matchesSearch && matchesCategory && matchesDate;
    }).toList();
  }

  Widget _buildFilters(List<Receipt> receipts) {
    final categories = <String>{};
    for (final r in receipts) {
      final cat = r.category?.trim();
      if (cat != null && cat.isNotEmpty) {
        categories.add(cat);
      }
    }
    final categoryItems = ['All', ...categories.toList()..sort()];
    final dateLabel = _dateRange == null
        ? 'Any date'
        : '${MaterialLocalizations.of(context).formatShortDate(_dateRange!.start)} - '
            '${MaterialLocalizations.of(context).formatShortDate(_dateRange!.end)}';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search store',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoryFilter ?? 'All',
            items: categoryItems
                .map(
                  (cat) => DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: const Icon(Icons.category_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) {
              setState(() {
                if (val == null || val == 'All') {
                  _categoryFilter = null;
                } else {
                  _categoryFilter = val;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(dateLabel),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_dateRange != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    tooltip: 'Clear date filter',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dateRange = null),
                  ),
                ),
            ],
          ),
          if (_searchQuery.isNotEmpty ||
              _categoryFilter != null ||
              _dateRange != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset filters'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recs = ref.watch(receiptsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F0FF),
      body: recs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No receipts yet.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your first receipt to get started!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }
          final filtered = _applyFilters(list);
          return Column(
            children: [
              _buildFilters(list),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No receipts match the selected filters.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.refresh(receiptsProvider.future),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final r = filtered[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
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
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      scheme.primary.withOpacity(0.1),
                                  child: Text(
                                    (r.store ?? 'U')[0].toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  r.store ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      r.date ?? '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (r.category != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              scheme.primary.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          displayCategory(r.category),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Text(
                                  r.total != null
                                      ? '₱${r.total!.toStringAsFixed(2)}'
                                      : '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ReceiptDetailPage(receipt: r),
                                    ),
                                  ).then(
                                    (_) => ref.refresh(receiptsProvider.future),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
