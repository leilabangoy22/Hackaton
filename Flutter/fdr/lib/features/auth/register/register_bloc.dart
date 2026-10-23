import 'package:fdr/features/auth/register/register_event.dart';
import 'package:fdr/features/auth/register/register_state.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:rxdart/rxdart.dart';

class RegisterBloc extends DisposeCallbackBaseBloc {
  final ApiService apiService;

  final _submitController = PublishSubject<RegisterSubmitted>();
  final _formChangeController = PublishSubject<RegisterFormChanged>();

  final BehaviorSubject<RegisterState> _stateController =
      BehaviorSubject<RegisterState>.seeded(RegisterInitial());

  RegisterBloc({required this.apiService}) : super(() {
  }) {
    _submitController.listen(_onRegisterSubmitted);
    _formChangeController.listen(_onRegisterFormChanged);
  }

  Function(RegisterSubmitted) get submit => _submitController.sink.add;
  Function(RegisterFormChanged) get formChanged =>
      _formChangeController.sink.add;


  Stream<RegisterState> get state$ => _stateController.stream;

  Stream<RegisterState> get state => state$;

  RegisterState get currentState => _stateController.value;

  void emit(RegisterState newState) {
    _stateController.sink.add(newState);
  }

  Future<void> _onRegisterSubmitted(RegisterSubmitted event) async {
    emit(RegisterLoading());

    try {
      if (event.email.isEmpty ||
          event.password.isEmpty ||
          event.name.isEmpty) {
        emit(RegisterError(message: "Please fill in all required fields"));
        return;
      }

      final response = await apiService.register({
        "name": event.name,
        "email": event.email,
        "password": event.password,
      });

      if (response["success"] == true) {
        emit(RegisterSuccess());
      } else {
        emit(RegisterError(
            message: response["message"] ?? "Registration failed"));
      }
    } catch (e) {
      emit(RegisterError(
          message: "Registration failed: ${e.toString()}"));
    }
  }

  void _onRegisterFormChanged(RegisterFormChanged event) {
    if (event.email.isNotEmpty &&
        event.password.isNotEmpty &&
        event.name.isNotEmpty) {
      emit(RegisterFormValid());
    } else {
      emit(RegisterFormInvalid());
    }
  }

  @override
  void dispose() {
    _submitController.close();
    _formChangeController.close();
    _stateController.close();
    super.dispose();
  }
}
