import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/auth/user/presentation/home/home_page.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';

abstract class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin<HomePage>, DisposeBagMixin {

  late final ApiService _apiService; 

  bool _isReportsLoading = true;
  String? _reportsError;

  List<ReportData> _allReports = []; 
  List<ReportData> _filteredReports = []; 
  
}