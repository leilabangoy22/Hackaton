// import 'package:fdr/services/api_service.dart';
// import 'package:bloc/bloc.dart';

// // Events
// abstract class RegisterEvent {}

// class RegisterSubmitted extends RegisterEvent {
//   final String email;
//   final String password;
//   final String name;
//   final String? phone;
//   final String role;
//   final bool isRescuer;
//   final String? team;
//   final List<String>? skills;

//    RegisterSubmitted({
//     required this.email,
//     required this.password,
//     required this.name,
//     this.phone,
//     required this.role,
//     required this.isRescuer,
//     this.team,
//     this.skills,
//   });
// }

// class RegisterFormChanged extends RegisterEvent {
//   final String email;
//   final String password;
//   final String name;
//   final String? phone;

//    RegisterFormChanged({
//     required this.email,
//     required this.password,
//     required this.name,
//     this.phone,
//   });
// }

// // States
// abstract class RegisterState {}

// class RegisterInitial extends RegisterState {}

// class RegisterLoading extends RegisterState {}

// class RegisterSuccess extends RegisterState {}

// class RegisterFormValid extends RegisterState {}

// class RegisterFormInvalid extends RegisterState {}

// class RegisterError extends RegisterState {
//   final String message;

//    RegisterError({required this.message});
// }

// // Bloc
// class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
//   final ApiService apiService;

//   RegisterBloc({required this.apiService}) : super(RegisterInitial()) {
//     on<RegisterSubmitted>(_onRegisterSubmitted);
//     on<RegisterFormChanged>(_onRegisterFormChanged);
//   }

//   void _onRegisterSubmitted(
//     RegisterSubmitted event,
//     Emitter<RegisterState> emit,
//   ) async {
//     emit(RegisterLoading());
    
//     try {
//       if (event.email.isEmpty || event.password.isEmpty || event.name.isEmpty) {
//         emit(RegisterError(message: 'Please fill in all required fields'));
//         return;
//       }

//       final response = await apiService.register({
//         'name': event.name,
//         'email': event.email,
//         'password': event.password,
//         'phone': event.phone,
//         'role': event.role,
//         'isRescuer': event.isRescuer,
//         if (event.team != null) 'team': event.team,
//         if (event.skills != null) 'skills': event.skills,
//       });

//       if (response['success'] == true) {
//         emit(RegisterSuccess());
//       } else {
//         final errorMessage = response['message'] ?? 'Registration failed';
//         emit(RegisterError(message: errorMessage));
//       }
//     } catch (e) {
//       emit(RegisterError(message: 'Registration failed: ${e.toString()}'));
//     }
//   }

//   void _onRegisterFormChanged(
//     RegisterFormChanged event,
//     Emitter<RegisterState> emit,
//   ) {
//     if (event.email.isNotEmpty && event.password.isNotEmpty && event.name.isNotEmpty) {
//       emit(RegisterFormValid());
//     } else {
//       emit(RegisterFormInvalid());
//     }
//   }
// }