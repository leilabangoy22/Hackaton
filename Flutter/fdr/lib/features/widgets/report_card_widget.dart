import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/widgets/map_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ReportCardWidget extends StatefulWidget {
  final ReportData report;
  final Color severityColor;
  final VoidCallback onBack;
  final ScrollController? scrollController;
  final dynamic onTap;

  const ReportCardWidget({
    super.key,
    required this.report,
    required this.severityColor,
    required this.onBack,
    this.scrollController,
    this.onTap,
  });

  @override
  State<ReportCardWidget> createState() => _ReportCardWidgetState();
}

class _ReportCardWidgetState extends State<ReportCardWidget> {
  bool _isPersonnelExpanded = false;

  String _getFormattedTime() {
    if (widget.report.timestamp == null) return 'N/A';
    final hour = widget.report.timestamp!.hour > 12
        ? widget.report.timestamp!.hour - 12
        : widget.report.timestamp!.hour;
    final period = widget.report.timestamp!.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${widget.report.timestamp!.minute.toString().padLeft(2, '0')} $period';
  }

  String _getFormattedDate() {
    if (widget.report.timestamp == null) return 'N/A';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[widget.report.timestamp!.month - 1];
    return '$month ${widget.report.timestamp!.day}, ${widget.report.timestamp!.year}';
  }

  Widget _buildCupertinoSeparator() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      color: CupertinoColors.systemGrey5,
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    Widget? customValueWidget,
    int maxLines = 5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
              letterSpacing: 0.3,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          customValueWidget ??
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? CupertinoColors.black,
                  decoration: TextDecoration.none,
                  height: 1.4,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey5, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (accentColor ?? widget.severityColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accentColor ?? widget.severityColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.systemGrey,
                    letterSpacing: 0.2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.black,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _getFormattedTime();
    final dateString = _getFormattedDate();

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: [
        // 1.Nav
        Container(
          color: CupertinoColors.white,
          padding: const EdgeInsets.only(
            left: 4,
            right: 16,
            top: 10,
            bottom: 10,
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(0),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    widget.onBack();
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.back,
                      size: 28,
                      color: CupertinoColors.systemBlue,
                    ),
                    SizedBox(width: 4),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    widget.report.title ?? 'Report Details',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.black,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 50),
            ],
          ),
        ),

        // 2. MAP AT THE TOP
        Container(
          height: 280,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: MapViewer(
            initialLocation: widget.report.location,
            disableSearch: true,
            disableLocationSelection: true,
            disableTapToPlace: true,
            mapScrollable: true,
            reportMarkers: {
              if (widget.report.location != null)
                Marker(
                  markerId: MarkerId(widget.report.reportId),
                  position: widget.report.location!,
                  infoWindow: InfoWindow(title: widget.report.title),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
            },
            onLocationSelected: (LatLng loc, String? name) {},
            onMapCreated: (GoogleMapController controller) {
              if (widget.report.location != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(widget.report.location!, 15),
                );
              }
            },
            enableZoom: true,
            enablePan: true,
            enableRotation: false,
            enableTilt: true,
          ),
        ),

        // 3. CONTENT SECTION
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.severityColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.report.status?.toString().toUpperCase() ?? 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.severityColor,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Title
              Text(
                widget.report.title ?? 'Flood Report',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.black,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Time & Date Info Cards
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Time',
                      value: timeString,
                      icon: CupertinoIcons.clock,
                      accentColor: CupertinoColors.systemBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Date',
                      value: dateString,
                      icon: CupertinoIcons.calendar,
                      accentColor: CupertinoColors.systemPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ID Card
              _buildInfoCard(
                label: 'Report ID',
                value: widget.report.reportId,
                icon: CupertinoIcons.doc_text,
                accentColor: CupertinoColors.systemGrey,
              ),

              _buildCupertinoSeparator(),

              // Severity
              _buildDetailRow(
                'SEVERITY',
                widget.report.severity?.toString() ?? 'HIGH',
                customValueWidget: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.report.severity?.toString().toUpperCase() ??
                          'HIGH SEVERITY',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.severityColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCupertinoSeparator(),

              // Reported By
              _buildDetailRow('REPORTED BY', 'You'),
              _buildCupertinoSeparator(),

              // Mobile Number
              _buildDetailRow('MOBILE NUMBER', '09XXXXXXXXX'),
              _buildCupertinoSeparator(),

              // Location Coordinates
              _buildDetailRow(
                'COORDINATES',
                widget.report.location != null
                    ? '${widget.report.location!.latitude.toStringAsFixed(6)}, ${widget.report.location!.longitude.toStringAsFixed(6)}'
                    : 'Location unavailable',
              ),
              _buildCupertinoSeparator(),

              // Explanation/Description
              const Text(
                'DESCRIPTION',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                  letterSpacing: 0.3,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey5),
                ),
                child: Text(
                  widget.report.description ??
                      'No detailed description provided by the user.',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: CupertinoColors.black,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // RESPONSE DETAILS Section
              const Text(
                'RESPONSE DETAILS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.black,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),

              // Personnel Assigned Card
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey5),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PERSONNEL ASSIGNED',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.systemGrey,
                        letterSpacing: 0.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ray H. Garcia, Jason C. Fernandez, Arnold Marlon K. Panigan, Roy H. Garcia, Jaycen C. Fernandez, Arnold Marlon K. Panigan, Jaycen C. Fernandez, Arnold Marlon K. Panigan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.black,
                        decoration: TextDecoration.none,
                        height: 1.4,
                      ),
                      maxLines: _isPersonnelExpanded ? 20 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () {
                          setState(() {
                            _isPersonnelExpanded = !_isPersonnelExpanded;
                          });
                        },
                        child: Text(
                          _isPersonnelExpanded ? 'Show Less' : 'Show More',
                          style: const TextStyle(
                            fontSize: 15,
                            color: CupertinoColors.systemBlue,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}
