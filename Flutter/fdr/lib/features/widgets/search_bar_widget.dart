import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final Function(String) onSubmitted;
  final Function(String)? onChanged;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.isSearching,
    required this.onSearch,
    required this.onClear,
    required this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Search city or place...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                        ),
                        onPressed: onClear,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.3),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: searchQuery.isNotEmpty
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: searchQuery.isNotEmpty && !isSearching
                  ? onSearch
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: isSearching
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.location_searching,
                        color: searchQuery.isNotEmpty
                            ? Colors.white
                            : Colors.grey[500],
                        size: 24,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
