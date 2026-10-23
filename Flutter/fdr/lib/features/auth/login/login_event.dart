part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final String name;
  final String password;

  const LoginSubmitted({required this.name, required this.password});

  @override
  List<Object> get props => [name, password];
}