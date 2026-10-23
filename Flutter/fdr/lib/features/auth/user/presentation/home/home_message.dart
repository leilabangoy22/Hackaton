// lib/features/auth/user/presentation/home/home_message.dart

abstract class HomeMessage {
  const HomeMessage();
}

abstract class LogoutMessage extends HomeMessage {
  const LogoutMessage();
}

class LogoutSuccessMessage extends LogoutMessage {
  const LogoutSuccessMessage();
}

class LogoutErrorMessage extends LogoutMessage {
  final String message;
  const LogoutErrorMessage(this.message);
}

abstract class UpdateAvatarMessage extends HomeMessage {
  const UpdateAvatarMessage();
}

class UpdateAvatarSuccessMessage extends UpdateAvatarMessage {
  const UpdateAvatarSuccessMessage();
}

class UpdateAvatarErrorMessage extends UpdateAvatarMessage {
  final String message;
  const UpdateAvatarErrorMessage(this.message);
}

class InvalidInformationMessage extends HomeMessage {
  const InvalidInformationMessage();
}