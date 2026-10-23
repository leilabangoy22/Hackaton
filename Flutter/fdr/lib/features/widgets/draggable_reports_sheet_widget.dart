import 'package:fdr/features/widgets/report_list_item.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/widgets/sheet_header_widget.dart';
import 'package:fdr/features/widgets/report_card_widget.dart';

class DraggableReportsSheetWidget extends StatefulWidget {
  final ValueNotifier<double> currentSheetSize;
  final double initialSheetSize;
  final double maxSheetSize;
  final String currentCityName;
  final String formattedDate;
  final TextEditingController searchController;
  final String searchQuery;
  final bool isSearching;
  final List<ReportData> filteredReports;
  final VoidCallback onSearch;
  final VoidCallback onSearchChanged;
  final VoidCallback onClear;
  final Function(String) onSubmitted;
  final Function(ReportData) onReportTap;
  final bool isLoading;
  final bool hasError;
  final bool usingMockData;
  final VoidCallback? onRetry;
  final ReportData? selectedReport;
  final VoidCallback? onClearSelectedReport;
  final ValueNotifier<bool>? preventSheetOpen;

  const DraggableReportsSheetWidget({
    super.key,
    required this.currentSheetSize,
    required this.initialSheetSize,
    required this.maxSheetSize,
    required this.currentCityName,
    required this.formattedDate,
    required this.searchController,
    required this.searchQuery,
    required this.isSearching,
    required this.filteredReports,
    required this.onSearch,
    required this.onSearchChanged,
    required this.onClear,
    required this.onSubmitted,
    required this.onReportTap,
    required this.usingMockData,
    this.selectedReport,
    this.onClearSelectedReport,
    required this.isLoading,
    required this.hasError,
    this.onRetry,
    this.preventSheetOpen, required DraggableScrollableController sheetController,
  });

  @override
  State<DraggableReportsSheetWidget> createState() =>
      _DraggableReportsSheetWidgetState();
}

class _DraggableReportsSheetWidgetState
    extends State<DraggableReportsSheetWidget> {
  late DraggableScrollableController _sheetController;
  bool _isDragging = false;
  DateTime? _lastTapTime;
  static const int _doubleTapTimeout = 300;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    
    _sheetController.addListener(() {
      widget.currentSheetSize.value = _sheetController.size;
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Color getSeverityColor(FloodSeverity? severity) {
    switch (severity) {
      case FloodSeverity.low:
        return Colors.yellow;
      case FloodSeverity.moderate:
        return Colors.orange;
      case FloodSeverity.high:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColorFromReport(ReportData? report) {
    if (report == null) return Colors.grey;

    if (report.status is ReportStatus) {
      switch (report.status as ReportStatus) {
        case ReportStatus.newReport:
        case ReportStatus.pending:
          return Colors.grey;
        case ReportStatus.assigned:
          return Colors.blue;
        case ReportStatus.inProgress:
          return Colors.orange;
        case ReportStatus.resolved:
          return Colors.green;
        case ReportStatus.complete:
          return Colors.green;
        case ReportStatus.ongoing:
          return Colors.orange;
        case ReportStatus.completed:
          return Colors.green;
        case ReportStatus.confirmed:
          return Colors.deepPurple;
      }
    } else if (report.status is String) {
      final status = (report.status as String).toLowerCase();
      if (status.contains('new') || status.contains('pending')) {
        return Colors.red;
      } else if (status.contains('progress')) {
        return Colors.orange;
      } else if (status.contains('resolved')) {
        return Colors.green;
      }
    }

    return Colors.grey;
  }

  Map<String, List<ReportData>> _groupReportsByMonth(List<ReportData> reports) {
    final Map<String, List<ReportData>> grouped = {};
    for (var report in reports) {
      final date = report.timestamp ?? DateTime.now();
      final key = DateFormat('yyyy-MM').format(date);
      grouped.putIfAbsent(key, () => []).add(report);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (var k in sortedKeys) k: grouped[k]!};
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load reports',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.onRetry != null)
              ElevatedButton(
                onPressed: widget.onRetry,
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.searchQuery.isEmpty
                        ? Icons.report_problem_outlined
                        : Icons.search_off,
                    color: Colors.grey[400],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.searchQuery.isEmpty
                        ? 'No reports available'
                        : 'No reports found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search terms',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      decoration: InputDecoration(
                        hintText: 'Search reports...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) => widget.onSearchChanged(),
                      onSubmitted: (value) => widget.onSubmitted(value),
                    ),
                  ),
                  if (widget.searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[500],
                        size: 18,
                      ),
                      onPressed: widget.onClear,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 20),
              onPressed: widget.onSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(
    BuildContext context,
    ScrollController scrollController,
    bool isExpanded,
  ) {
    final groupedReports = _groupReportsByMonth(widget.filteredReports);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final List<Widget> reportWidgets = [];

    reportWidgets.add(
      SheetHeaderWidget(
        isExpanded: isExpanded,
        currentCityName: widget.currentCityName,
        formattedDate: widget.formattedDate,
        searchController: widget.searchController,
        searchQuery: widget.searchQuery,
        isSearching: widget.isSearching,
        filteredReportsCount: widget.filteredReports.length,
        onSearch: widget.onSearch,
        onClear: widget.onClear,
        onSubmitted: widget.onSubmitted,
      ),
    );

    groupedReports.forEach((month, reports) {
      reportWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Text(
            DateFormat('MMMM yyyy').format(DateTime.parse('$month-01')),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      reportWidgets.addAll(
        reports.map(
          (report) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final now = DateTime.now();
              final shouldPrevent = widget.preventSheetOpen?.value == true ||
                  (_lastTapTime != null &&
                      now.difference(_lastTapTime!).inMilliseconds <
                          _doubleTapTimeout);

              if (!shouldPrevent) {
                widget.onReportTap(report);
              }
              _lastTapTime = now;
            },
            child: ReportListItemWidget(
              report: report,
              onTap: () {
                widget.onReportTap(report);
              },
              severityColor: getSeverityColor(report.severity),
            ),
          ),
        ),
      );
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isDragging = true;
        } else if (notification is ScrollEndNotification) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _isDragging = false;
          });
        }
        return false;
      },
      child: ListView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(bottom: 80 + bottomPadding),
        children: reportWidgets,
      ),
    );
  }

  void _animateToSize(double targetSize) {
    _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: widget.initialSheetSize,
      minChildSize: widget.initialSheetSize,
      maxChildSize: widget.maxSheetSize,
      snap: true,
      snapSizes: const [0.25, 0.5, 0.9],
      snapAnimationDuration: const Duration(milliseconds: 150),
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  final currentSize = widget.currentSheetSize.value;
                  final isMinimized = currentSize <= widget.initialSheetSize + 0.05;
                  _animateToSize(isMinimized ? 0.9 : widget.initialSheetSize);
                },
                child: Container(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 10.0),
                  width: double.infinity,
                  child: Center(
                    child: Container(
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Content area
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.currentSheetSize,
                  builder: (context, size, child) {
                    final isExpanded = size > widget.initialSheetSize + 0.05;

                    final shouldPreventSheet = 
                        widget.preventSheetOpen?.value == true;
                    
                    if (widget.selectedReport != null &&
                        widget.onClearSelectedReport != null &&
                        !shouldPreventSheet) {
                      return ReportCardWidget(
                        report: widget.selectedReport!,
                        severityColor: _getSeverityColorFromReport(
                          widget.selectedReport,
                        ),
                        onBack: widget.onClearSelectedReport!,
                      );
                    }

                    if (widget.isLoading) {
                      return _buildLoadingState();
                    }

                    if (widget.hasError) {
                      return _buildErrorState();
                    }

                    if (widget.filteredReports.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildReportList(
                      context,
                      scrollController,
                      isExpanded,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}