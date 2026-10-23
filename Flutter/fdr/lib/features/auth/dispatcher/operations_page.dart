import 'package:fdr/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:fdr/services/api_service.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});
  static const routeName = '/operations';

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedRows = {};
  final ApiService _apiService = ApiService();

  List<ReportData> _allReports = [];
  List<ReportData> _operationsHistory = [];
  List<dynamic> _personnelList = [];
  bool _isLoading = true;
  String? _error;
  bool _usingMockData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ReportData> _generateMockReports() {
    return [
      ReportData(
        reportId: 'REP-001',
        title: 'Flood in Downtown Area',
        description:
            'Major flooding reported in central business district with multiple vehicles stranded.',
        address: '123 Main Street, Downtown',
        status: ReportStatus.inProgress,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        reportedBy: 'User',
        phoneNumber: '097765656545',
      ),
      ReportData(
        reportId: 'REP-002',
        title: 'River Overflow - Residential Zone',
        description:
            'River has overflowed affecting residential areas. Evacuation needed.',
        address: '456 River Road, North District',
        status: ReportStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        reportedBy: 'User',
        phoneNumber: '097765656545',
      ),
      ReportData(
        reportId: 'REP-003',
        title: 'Flash Flood Warning',
        description:
            'Flash flood reported in low-lying areas. Immediate response required.',
        address: '789 Valley View, East Side',
        status: ReportStatus.newReport,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        reportedBy: 'User',
        phoneNumber: '097765656545',
      ),
    ];
  }

  List<ReportData> _generateMockOperationsHistory() {
    return [
      ReportData(
        reportId: 'REP-H001',
        title: 'Completed: Market Street Flood',
        description:
            'Flooding situation resolved. All residents evacuated safely.',
        address: '321 Market Street, West End',
        status: ReportStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        reportedBy: 'User',
        phoneNumber: '097765656545',
      ),
      ReportData(
        reportId: 'REP-H002',
        title: 'Resolved: Park Area Drainage',
        description: 'Drainage system restored. Water levels back to normal.',
        address: '654 Park Avenue, Central Park',
        status: ReportStatus.resolved,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        reportedBy: 'User',
        phoneNumber: '097765656545',
      ),
    ];
  }

  List<dynamic> _generateMockPersonnel() {
    return [
      {
        'name': 'John Smith',
        'role': 'Team Leader',
        'status': 'Active',
        'phone': '+1-555-0101',
      },
      {
        'name': 'Maria Garcia',
        'role': 'Rescue Specialist',
        'status': 'Active',
        'phone': '+1-555-0102',
      },
      {
        'name': 'David Chen',
        'role': 'Medical Officer',
        'status': 'On Break',
        'phone': '+1-555-0103',
      },
      {
        'name': 'Sarah Johnson',
        'role': 'Boat Operator',
        'status': 'Active',
        'phone': '+1-555-0104',
      },
      {
        'name': 'Robert Brown',
        'role': 'Logistics Coordinator',
        'status': 'Available',
        'phone': '+1-555-0105',
      },
    ];
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _usingMockData = false;
      });

      final reportsResponse = await _apiService.getAllReports(
        offset: 0,
        limit: 100,
      );
      final List<ReportData> allReports = [];

      if (reportsResponse is Map && reportsResponse['data'] is List) {
        final dataList = reportsResponse['data'] as List;
        for (var item in dataList) {
          try {
            final report = ReportData.fromJson(item as Map<String, dynamic>);
            allReports.add(report);
          } catch (e) {
            print('Error parsing report: $e');
          }
        }
      }

      final personnelResponse = await _apiService.getRescuerList();
      List<dynamic> personnelList = [];

      if (personnelResponse is Map && personnelResponse['data'] is List) {
        personnelList = personnelResponse['data'] as List;
      } else if (personnelResponse is List) {
        personnelList = personnelResponse;
      }

      bool useMockData = allReports.isEmpty && personnelList.isEmpty;

      if (useMockData) {
        allReports.addAll(_generateMockReports());
        personnelList.addAll(_generateMockPersonnel());
      }

      final operationsHistory = allReports
          .where(
            (report) =>
                report.status == ReportStatus.completed ||
                report.status == ReportStatus.resolved,
          )
          .toList();

      if (operationsHistory.isEmpty && useMockData) {
        operationsHistory.addAll(_generateMockOperationsHistory());
        allReports.addAll(_generateMockOperationsHistory());
      }

      setState(() {
        _allReports = allReports;
        _operationsHistory = operationsHistory;
        _personnelList = personnelList;
        _isLoading = false;
        _usingMockData = useMockData;
      });
    } catch (e) {
      print('Error loading data: $e');

      final mockReports = _generateMockReports();
      final mockHistory = _generateMockOperationsHistory();
      final mockPersonnel = _generateMockPersonnel();

      setState(() {
        _allReports = mockReports;
        _operationsHistory = mockHistory;
        _personnelList = mockPersonnel;
        _isLoading = false;
        _usingMockData = true;
        _error = 'Using demo data. Real data unavailable: ${e.toString()}';
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _showProfileMenu(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final double maxWidth = screenWidth > 600 ? 400 : screenWidth * 0.9;
    final double avatarRadius = screenWidth > 600 ? 40 : 32;
    final double titleFontSize = screenWidth > 600 ? 20 : 18;
    final double subtitleFontSize = screenWidth > 600 ? 14 : 12;
    final double menuItemFontSize = screenWidth > 600 ? 16 : 14;
    final double iconSize = screenWidth > 600 ? 22 : 20;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Draggable Scroll Sheet
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    width: maxWidth,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 600 ? 24 : 20,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.person,
                            size: avatarRadius,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 16 : 12),
                        Text(
                          'Dispatcher',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'dispatcher@fdr.com',
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 24 : 20),
                        _buildProfileMenuItem(
                          icon: Icons.person_outline,
                          title: 'Profile Settings',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        _buildProfileMenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        _buildProfileMenuItem(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        Divider(height: 32),
                        _buildProfileMenuItem(
                          icon: Icons.logout,
                          title: 'Logout',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          color: Colors.red.shade600,
                          onTap: () {
                            Navigator.pop(context);
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double iconSize,
    required double fontSize,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: color ?? Color(0xFF1D1D1F)),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: color ?? Color(0xFF1D1D1F),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: iconSize - 2,
              color: Color(0xFF6E6E73),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.85;
    final titleFontSize = screenWidth > 600 ? 20.0 : 18.0;
    final contentFontSize = screenWidth > 600 ? 16.0 : 14.0;
    final buttonFontSize = screenWidth > 600 ? 16.0 : 14.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(screenWidth > 600 ? 24 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontSize: contentFontSize,
                  color: Color(0xFF6E6E73),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF6E6E73),
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth > 600 ? 20 : 16,
                        vertical: screenWidth > 600 ? 12 : 10,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth > 600 ? 24 : 20,
                        vertical: screenWidth > 600 ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.water_drop,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Flood Detection & Rescue',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1D1D1F),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Operations Management',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildAppBarButton('Dashboard', false, () {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.dispatcherDashboard);
          }),
          const SizedBox(width: 8),
          _buildAppBarButton('Operations', true, () {}),
          const SizedBox(width: 20),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            child: IconButton(
              icon: const Icon(
                Icons.person_outline,
                color: Color(0xFF1D1D1F),
                size: 24,
              ),
              onPressed: () => _showProfileMenu(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Column(
        children: [
          if (_usingMockData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DEMO MODE — Showing sample data for demonstration',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.orange.shade700,
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() {
                        _usingMockData = false;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Color(0xFF6E6E73),
              indicatorColor: Colors.blue.shade700,
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grid_view, size: 18),
                      const SizedBox(width: 8),
                      const Text('Operations'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 18),
                      const SizedBox(width: 8),
                      const Text('History'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18),
                      const SizedBox(width: 8),
                      const Text('Personnel'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _tabController.index == 0
                ? _buildOperationsTab()
                : _tabController.index == 1
                ? _buildOperationsHistoryTab()
                : _buildPersonnelListTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarButton(
    String title,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isSelected
            ? Colors.blue.shade600
            : const Color(0xFF6E6E73),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isSelected
            ? Colors.blue.shade50.withOpacity(0.5)
            : Colors.transparent,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildOperationsTab() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final pendingReports = _allReports
        .where(
          (r) =>
              r.status == ReportStatus.pending ||
              r.status == ReportStatus.newReport,
        )
        .toList();
    final assignedReports = _allReports
        .where((r) => r.status == ReportStatus.inProgress)
        .toList();
    final completedReports = _allReports
        .where(
          (r) =>
              r.status == ReportStatus.completed ||
              r.status == ReportStatus.resolved,
        )
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.blue.shade600,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Pending',
                      pendingReports.length.toString(),
                      Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Assigned',
                      assignedReports.length.toString(),
                      Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Completed',
                      completedReports.length.toString(),
                      Colors.green.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildPendingRequestsContainer(pendingReports),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: _buildRecentRescuesContainer(completedReports),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildAssignedRescuesContainer(assignedReports),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequestsContainer(List<ReportData> pendingReports) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Rescue Requests (${pendingReports.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Assign rescuers to these requests',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6E6E73),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingReports.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingReports.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = pendingReports[index];
                return _buildPendingRequestCard(report);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentRescuesContainer(List<ReportData> completedReports) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Rescues (${completedReports.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recently completed operations',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6E6E73),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          if (completedReports.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No recent completed rescues',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedReports.length > 5
                  ? 5
                  : completedReports.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = completedReports[index];
                return _buildRecentRescueCard(report);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAssignedRescuesContainer(List<ReportData> assignedReports) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assigned Rescues (${assignedReports.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ongoing operations and their assigned teams',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6E6E73),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          if (assignedReports.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No active assigned rescues',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignedReports.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = assignedReports[index];
                return _buildAssignedRescueCard(report);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentRescueCard(ReportData report) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.title ?? 'Untitled',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            report.address ?? 'No address',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6E6E73)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedRescueCard(ReportData report) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  report.title ?? 'Flood Report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.person_outline,
                  'Reported by: ${report.reportedBy ?? "User"}',
                ),
                _buildInfoRow(
                  Icons.phone_outlined,
                  report.phoneNumber ?? '+63 912 345 6789',
                ),
                _buildInfoRow(
                  Icons.water_drop_outlined,
                  '${report.floodHeight ?? 0.5}m',
                ),
                _buildInfoRow(
                  Icons.access_time_outlined,
                  _formatDate(report.createdAt ?? report.timestamp),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Assigned Rescue Personnel',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6E6E73),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'by Member1 B. Fernandez',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1D1D1F)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Severity Level',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                            Text(
                              'High Severity',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                        Text(
                          'Ongoing',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ID: ${report.reportId}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6E6E73),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showReportDetails(report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View Progress',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E6E73),
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(ReportData report) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  report.title ?? 'Flood Report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID: ${report.reportId}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E6E73),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.person_outline,
            'Reported by: ${report.reportedBy ?? "User"}',
          ),
          _buildInfoRow(
            Icons.phone_outlined,
            report.phoneNumber ?? '+63 912 345 6789',
          ),
          _buildInfoRow(
            Icons.water_drop_outlined,
            '${report.floodHeight ?? 0.5}m',
          ),
          _buildInfoRow(
            Icons.access_time_outlined,
            _formatDate(report.createdAt ?? report.timestamp),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _showReportDetails(report),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 40,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'View Request',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedMissionCard(ReportData report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ID: ${report.reportId}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6E6E73),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          report.title ?? 'Completed Mission',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: -0.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          Icons.person_outline,
          'Reported by: ${report.reportedBy ?? "User"}',
        ),
        _buildInfoRow(
          Icons.phone_outlined,
          report.phoneNumber ?? '+63 912 345 6789',
        ),
        _buildInfoRow(
          Icons.water_drop_outlined,
          '${report.floodHeight ?? 0.5}m',
        ),
        _buildInfoRow(
          Icons.access_time_outlined,
          _formatDate(report.createdAt ?? report.timestamp),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Status: ',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6E6E73),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Completed On: ${_formatTimeOnly(report.createdAt ?? report.timestamp)}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6E6E73)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF1D1D1F),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeOnly(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _buildOperationsHistoryTab() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.blue.shade600,
      child: _operationsHistory.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No operations history',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              itemCount: _operationsHistory.length,
              itemBuilder: (context, index) {
                final report = _operationsHistory[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment_turned_in,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      report.title ?? 'Completed Operation',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        report.description ?? 'No description',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    trailing: Text(
                      _formatDate(report.createdAt ?? report.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6E6E73),
                        letterSpacing: -0.2,
                      ),
                    ),
                    onTap: () => _showReportDetails(report),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPersonnelListTab() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.blue.shade600,
      child: _personnelList.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No personnel data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              itemCount: _personnelList.length,
              itemBuilder: (context, index) {
                final personnel = _personnelList[index];
                final name =
                    personnel['name'] ?? personnel['full_name'] ?? 'Unknown';
                final role =
                    personnel['role'] ?? personnel['position'] ?? 'Rescuer';
                final status = personnel['status'] ?? 'Active';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'Active'
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: status == 'Active'
                              ? Colors.green.shade200
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'Active'
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(ReportStatus? status) {
    switch (status) {
      case ReportStatus.newReport:
      case ReportStatus.pending:
        return Colors.orange.shade600;
      case ReportStatus.inProgress:
        return Colors.blue.shade600;
      case ReportStatus.completed:
      case ReportStatus.resolved:
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(ReportStatus? status) {
    return status?.toString().split('.').last ?? 'Unknown';
  }

  String _getSeverityText(ReportStatus? status) {
    if (status == ReportStatus.newReport || status == ReportStatus.pending) {
      return 'High';
    } else if (status == ReportStatus.inProgress) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  Color _getSeverityColor(ReportStatus? status) {
    if (status == ReportStatus.newReport || status == ReportStatus.pending) {
      return Colors.red.shade600;
    } else if (status == ReportStatus.inProgress) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showReportDetails(ReportData report) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 450.0 : screenWidth * 0.9;
    final titleFontSize = screenWidth > 600 ? 18.0 : 16.0;
    final contentFontSize = screenWidth > 600 ? 14.0 : 13.0;
    final labelFontSize = screenWidth > 600 ? 12.0 : 11.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(screenWidth > 600 ? 24 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report #${report.reportId}',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Title',
                report.title ?? 'N/A',
                labelFontSize,
                contentFontSize,
              ),
              _buildDetailRow(
                'Description',
                report.description ?? 'N/A',
                labelFontSize,
                contentFontSize,
              ),
              if (report.address != null)
                _buildDetailRow(
                  'Location',
                  report.address!,
                  labelFontSize,
                  contentFontSize,
                ),
              _buildDetailRow(
                'Status',
                _getStatusText(report.status),
                labelFontSize,
                contentFontSize,
              ),
              _buildDetailRow(
                'Created',
                _formatDate(report.createdAt ?? report.timestamp),
                labelFontSize,
                contentFontSize,
              ),
              if (_usingMockData)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Demo Data',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 600 ? 20 : 16,
                      vertical: screenWidth > 600 ? 12 : 10,
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: contentFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    double labelSize,
    double valueSize,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: labelSize,
              color: Color(0xFF6E6E73),
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              color: Color(0xFF1D1D1F),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportActions(ReportData report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.visibility, size: 20),
              title: const Text(
                'View Details',
                style: TextStyle(fontSize: 14, letterSpacing: -0.2),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReportDetails(report);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, size: 20),
              title: const Text(
                'Edit Report',
                style: TextStyle(fontSize: 14, letterSpacing: -0.2),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind, size: 20),
              title: const Text(
                'Assign Personnel',
                style: TextStyle(fontSize: 14, letterSpacing: -0.2),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _deleteSelectedOperations() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Delete functionality coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Filters',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Filter functionality coming soon',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.blue.shade600),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _exportOperations() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Export functionality coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _createNewOperation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Create new operation functionality coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
