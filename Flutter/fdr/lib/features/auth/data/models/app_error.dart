import 'package:dart_either/dart_either.dart';
import 'package:fdr/features/utils/unit.dart';

class AppError {
  final String message;

  const AppError(this.message);

  @override
  String toString() => 'AppError: $message';
}

typedef Result<T> = Either<AppError, T>;
typedef UnitResult = Result<Unit>;