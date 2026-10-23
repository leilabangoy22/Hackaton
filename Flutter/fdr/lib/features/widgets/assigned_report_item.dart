
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/widgets/real_time_map_viewer.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AssignedRescueItem extends StatelessWidget {
  final ReportData data;
  final VoidCallback onRefresh;
  final Function(ReportData) onViewProgress;

  const AssignedRescueItem({
    required this.data,
    required this.onRefresh,
    required this.onViewProgress,
    super.key,
  });

  bool _isConfirmedStatus() {
    final responseStatus = data.responseStatus?.toLowerCase();
    final reportStatus = data.reportStatus?.toLowerCase();

    return responseStatus == 'confirmed' || reportStatus == 'confirmed';
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = _isConfirmedStatus();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title ?? 'Flood Report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailLine(data.description ?? 'No description'),
                if (data.address != null) _buildDetailLine(data.address!),
                _buildDetailLine(
                  'Created: ${_formatDate(data.createdAt ?? data.timestamp)}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                  'Status',
                  _getDetailedStatusText(data),
                  _getStatusColor(data),
                ),
                const SizedBox(width: 50),
                const SizedBox(height: 10),
                _buildStatusRow(
                  'Severity',
                  _getSeverityText(data.status),
                  Colors.orange.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${data.reportId}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E6E73),
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (isConfirmed)
                ElevatedButton(
                  onPressed: () => _openRealTimeMap(context, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    'View Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Awaiting Confirmation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openRealTimeMap(BuildContext context, ReportData report) {
    final location = LatLng(
      report.latitude ?? 14.5995,
      report.longitude ?? 120.9842,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealTimeMapViewer(
          initialLocation: location,
          reportId: report.reportId,
          rescuerId: report.assignedTo?.toString(),
          assignmentId: int.tryParse(report.reportId ?? '0'),
        ),
      ),
    );
  }

  Color _getStatusColor(ReportData report) {
    final responseStatus = report.responseStatus?.toLowerCase();
    final reportStatus = report.reportStatus?.toLowerCase();

    if (responseStatus == 'confirmed' || reportStatus == 'confirmed') {
      return Colors.green.shade600;
    } else if (responseStatus == 'assigned' || reportStatus == 'assigned') {
      return Colors.blue.shade600;
    } else if (responseStatus == 'pending' || reportStatus == 'pending') {
      return Colors.orange.shade600;
    } else if (responseStatus == 'completed' ||
        reportStatus == 'completed' ||
        responseStatus == 'resolved' ||
        reportStatus == 'resolved') {
      return Colors.green.shade800;
    }

    return Colors.grey.shade600;
  }

  Widget _buildDetailLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1D1D1F),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6E6E73),
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

String _getDetailedStatusText(ReportData report) {
  final responseStatus = report.responseStatus?.toUpperCase();
  final reportStatus = report.reportStatus?.toUpperCase();
  final hasAssignedTo = report.assignedTo != null;

  if (responseStatus != null) return responseStatus;
  if (reportStatus != null) return reportStatus;
  if (hasAssignedTo) return 'ASSIGNED';

  return _getStatusText(report.status);
}

  String _getStatusText(ReportStatus? status) {
    return status?.toString().split('.').last ?? 'Unknown';
  }

  String _getSeverityText(ReportStatus? status) {
    if (status == ReportStatus.newReport || status == ReportStatus.pending) {
      return 'HIGH';
    } else if (status == ReportStatus.inProgress) {
      return 'MEDIUM';
    } else {
      return 'LOW';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.month}/${date.day}/${date.year}';
  }
}
