import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:flutter/material.dart';

class ReportListItemWidget extends StatelessWidget {
  final ReportData report;
  final VoidCallback? onTap;
  final Color severityColor;

  const ReportListItemWidget({
    super.key,
    required this.report,
    required this.severityColor,
    this.onTap,
  });

  String _getFormattedTime() {
    if (report.timestamp == null) return 'N/A';
    final hour = report.timestamp!.hour > 12
        ? report.timestamp!.hour - 12
        : report.timestamp!.hour;
    final period = report.timestamp!.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${report.timestamp!.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _getFormattedTime();

    return Container(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity indicator
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              // Main content (title + address)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        report.title ?? 'Flood Report',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600, 
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis, 
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Address
                    Text(
                      report.address ?? 'Unknown Address',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Timestamp
              Padding(
                padding: const EdgeInsets.only(top: 2.0, left: 8.0),
                child: Text(
                  timeString,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
