import 'package:dart_either/dart_either.dart';
import 'package:fdr/features/auth/data/models/app_error.dart';
import 'package:fdr/features/utils/unit.dart';
import 'package:fdr/services/api_service.dart';

class SendResetPasswordEmailUseCase {
  final ApiService _apiService;

  const SendResetPasswordEmailUseCase(this._apiService);

  Future<UnitResult> call(String email) async {
    try {
      await _apiService.forgotPassword(email);
      
      return Right(unit);
      
    } catch (e) {
      String errorMessage = 'Failed to send reset password email';
      
      if (e.toString().contains('email') || e.toString().contains('not found')) {
        errorMessage = 'No account found with this email address';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split(':').last.trim();
      }
      
      return Left(AppError(errorMessage));
    }
  }
}