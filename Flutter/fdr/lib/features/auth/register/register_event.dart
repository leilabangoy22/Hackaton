abstract class RegisterEvent {}

class RegisterSubmitted extends RegisterEvent {
  final String email;
  final String password;
  final String name;
  final String? phone;
  final String role;
  final bool isRescuer;
  final String? team;
  final List<String>? skills;

   RegisterSubmitted({
    required this.email,
    required this.password,
    required this.name,
    this.phone,
    required this.role,
    required this.isRescuer,
    this.team,
    this.skills,
  });
}

class RegisterFormChanged extends RegisterEvent {
  final String email;
  final String password;
  final String name;
  final String? phone;

   RegisterFormChanged({
    required this.email,
    required this.password,
    required this.name,
    this.phone,
  });
}