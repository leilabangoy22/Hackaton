import 'package:fdr/features/auth/data/models/app_error.dart';
import 'package:fdr/services/api_service.dart';
import 'package:fdr/features/utils/unit.dart';
import 'package:dart_either/dart_either.dart';

class ChangePasswordUseCase {
  final ApiService _apiService;

  const ChangePasswordUseCase(this._apiService);

  Future<UnitResult> call({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiService.changePassword({
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      
      return Right(unit); 
      
    } catch (e) {
      String errorMessage = 'Failed to change password';
      
      if (e.toString().contains('current_password') || 
          e.toString().contains('Current password')) {
        errorMessage = 'Current password is incorrect';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split(':').last.trim();
      }
      
      return Left(AppError(errorMessage));
    }
  }
}