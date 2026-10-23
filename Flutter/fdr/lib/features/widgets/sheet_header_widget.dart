import 'package:flutter/material.dart';
import 'search_bar_widget.dart';

class SheetHeaderWidget extends StatelessWidget {
  final bool isExpanded;
  final String currentCityName;
  final String formattedDate;
  final TextEditingController searchController;
  final String searchQuery;
  final bool isSearching;
  final int filteredReportsCount;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final Function(String) onSubmitted;

  const SheetHeaderWidget({
    super.key,
    required this.isExpanded,
    required this.currentCityName,
    required this.formattedDate,
    required this.searchController,
    required this.searchQuery,
    required this.isSearching,
    required this.filteredReportsCount,
    required this.onSearch,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded)
          SearchBarWidget(
            controller: searchController,
            searchQuery: searchQuery,
            isSearching: isSearching,
            onSearch: onSearch,
            onClear: onClear,
            onSubmitted: onSubmitted,
          ),
        SizedBox(height: isExpanded ? 20 : 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0,),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentCityName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isExpanded) 
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: isExpanded ? 12 : 16),

        // Search results hint
        if (isExpanded && searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filteredReportsCount == 0
                          ? 'No reports found in this location'
                          : 'Found $filteredReportsCount report${filteredReportsCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isExpanded && searchQuery.isNotEmpty) const SizedBox(height: 12),
      ],
    );
  }
}