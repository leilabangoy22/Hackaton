import 'package:dart_either/dart_either.dart';
import 'package:fdr/features/auth/data/models/app_error.dart';
import 'package:fdr/features/utils/unit.dart';
import 'package:fdr/services/api_service.dart';

class ResetPasswordUseCase {
  final ApiService _apiService;

  const ResetPasswordUseCase(this._apiService);

  Future<UnitResult> call({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _apiService.resetPassword(token, newPassword);
      
      return Right(unit);
      
    } catch (e) {
      String errorMessage = 'Failed to reset password';
      
      if (e.toString().contains('token') || e.toString().contains('invalid')) {
        errorMessage = 'Invalid or expired reset token';
      } else if (e.toString().contains('password')) {
        errorMessage = 'New password does not meet requirements';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split(':').last.trim();
      }
      
      return Left(AppError(errorMessage));
    }
  }
}