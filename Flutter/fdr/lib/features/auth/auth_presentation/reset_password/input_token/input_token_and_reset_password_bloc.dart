// lib/features/auth/auth_presentation/reset_password/input_token/input_token_and_reset_password_bloc.dart
import 'dart:async';
import 'package:disposebag/disposebag.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:rxdart/rxdart.dart';

class InputTokenAndResetPasswordBloc extends DisposeCallbackBaseBloc {
  final Function(String) tokenChanged;
  final Function(String) newPasswordChanged;
  final Function(String) confirmPasswordChanged;
  final Function() submit;

  final Stream<String?> tokenError$;
  final Stream<String?> newPasswordError$;
  final Stream<String?> confirmPasswordError$;
  final Stream<bool> isLoading$;
  final Stream<ResetPasswordMessage> message$;

  InputTokenAndResetPasswordBloc._({
    required this.tokenChanged,
    required this.newPasswordChanged,
    required this.confirmPasswordChanged,
    required this.submit,
    required this.tokenError$,
    required this.newPasswordError$,
    required this.confirmPasswordError$,
    required this.isLoading$,
    required this.message$,
    required Function() dispose,
  }) : super(dispose);

  factory InputTokenAndResetPasswordBloc(ApiService apiService) {
    final tokenController = BehaviorSubject.seeded('');
    final newPasswordController = BehaviorSubject.seeded('');
    final confirmPasswordController = BehaviorSubject.seeded('');
    final submitController = PublishSubject<void>();
    final isLoadingController = BehaviorSubject.seeded(false);

    final tokenError$ = tokenController.stream.map(_validateToken).shareValue();
    final newPasswordError$ = newPasswordController.stream.map(_validatePassword).shareValue();
    final confirmPasswordError$ = Rx.combineLatest2(
      newPasswordController,
      confirmPasswordController,
      (newPass, confirmPass) => _validatePasswordMatch(newPass, confirmPass),
    ).shareValue();

    final message$ = submitController
        .withLatestFrom3(
          tokenError$,
          newPasswordError$,
          confirmPasswordError$,
          (_, tokenError, newPassError, confirmPassError) =>
              (tokenError, newPassError, confirmPassError),
        )
        .where((errors) => errors.$1 == null && errors.$2 == null && errors.$3 == null)
        .withLatestFrom3(
          tokenController,
          newPasswordController,
          confirmPasswordController,
          (_, token, newPass, confirmPass) => (token, newPass),
        )
        .exhaustMap((tuple) => _resetPassword(apiService, tuple.$1, tuple.$2, isLoadingController))
        .publish();

    return InputTokenAndResetPasswordBloc._(
      tokenChanged: tokenController.add,
      newPasswordChanged: newPasswordController.add,
      confirmPasswordChanged: confirmPasswordController.add,
      submit: () => submitController.add(null),
      tokenError$: tokenError$,
      newPasswordError$: newPasswordError$,
      confirmPasswordError$: confirmPasswordError$,
      isLoading$: isLoadingController,
      message$: message$,
      dispose: DisposeBag([
        tokenController,
        newPasswordController,
        confirmPasswordController,
        submitController,
        isLoadingController,
        message$.connect(),
      ]).dispose,
    );
  }

  static String? _validateToken(String token) {
    if (token.isEmpty) {
      return 'Token cannot be empty';
    }
    if (token.length < 6) {
      return 'Token must be at least 6 characters';
    }
    return null;
  }

  static String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? _validatePasswordMatch(String newPassword, String confirmPassword) {
    if (confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (newPassword != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  static Stream<ResetPasswordMessage> _resetPassword(
    ApiService apiService,
    String token,
    String newPassword,
    BehaviorSubject<bool> isLoadingController,
  ) async* {
    isLoadingController.add(true);
    
    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
  
   
      isLoadingController.add(false);
      yield ResetPasswordSuccessMessage();
      
    } catch (e) {
      isLoadingController.add(false);
      yield ResetPasswordErrorMessage('Failed to reset password: ${e.toString()}');
    }
  }
}

abstract class ResetPasswordMessage {}

class ResetPasswordSuccessMessage extends ResetPasswordMessage {}

class ResetPasswordErrorMessage extends ResetPasswordMessage {
  final String message;
  ResetPasswordErrorMessage(this.message);
}