import 'package:fdr/features/auth/data/models/user_role.dart';

sealed class LoginMessage {}

class LoginSuccessMessage implements LoginMessage {}

class LoginSuccessMessageWithRole implements LoginMessage {
  final UserRole userRole;
  LoginSuccessMessageWithRole(this.userRole);
}

class LoginErrorMessage implements LoginMessage {
  final String message;
  LoginErrorMessage(this.message);
}

class InvalidInformationMessage implements LoginMessage {}