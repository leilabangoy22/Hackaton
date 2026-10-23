import 'user_and_token.dart';

abstract class AuthenticationState {
  const AuthenticationState();
}

class UnauthenticatedState extends AuthenticationState {
  const UnauthenticatedState();
}

class AuthenticatedState extends AuthenticationState {
  final UserAndToken? userAndToken;

  const AuthenticatedState({this.userAndToken});

  factory AuthenticatedState.builder(void Function(AuthenticatedStateBuilder) updates) {
    final builder = AuthenticatedStateBuilder();
    updates(builder);
    return builder.build();
  }
}

class AuthenticatedStateBuilder {
  UserAndToken? userAndToken;

  void $update(void Function(AuthenticatedStateBuilder) updates) {
    updates(this);
  }

  AuthenticatedState build() {
    return AuthenticatedState(userAndToken: userAndToken);
  }
}

extension AuthenticatedStateExt on AuthenticatedState {
  AuthenticatedState Function(void Function(AuthenticatedStateBuilder)) get $ {
    return (updates) => AuthenticatedState.builder(updates);
  }
}