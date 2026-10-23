import 'dart:async';
import 'package:disposebag/disposebag.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:rxdart/rxdart.dart';

class ChangePasswordBloc extends DisposeCallbackBaseBloc {
  final VoidCallback submit;
  final ValueChanged<String> currentPasswordChanged;
  final ValueChanged<String> newPasswordChanged;
  final Stream<ChangePasswordMessage> message$;
  final Stream<String?> currentPasswordError$;
  final Stream<String?> newPasswordError$;
  final Stream<bool> isLoading$;

  ChangePasswordBloc._({
    required this.submit,
    required this.currentPasswordChanged,
    required this.newPasswordChanged,
    required this.message$,
    required this.currentPasswordError$,
    required this.newPasswordError$,
    required this.isLoading$,
    required VoidCallback dispose,
  }) : super(dispose);

  factory ChangePasswordBloc(ApiService apiService) {
    final currentPasswordController = BehaviorSubject.seeded('');
    final newPasswordController = BehaviorSubject.seeded('');
    final submitController = PublishSubject<void>();
    final isLoadingController = BehaviorSubject.seeded(false);

    final currentPasswordError$ = currentPasswordController.stream
        .map(_validateCurrentPassword)
        .shareValue();

    final newPasswordError$ = Rx.combineLatest2(
      currentPasswordController.stream,
      newPasswordController.stream,
      _validateNewPassword,
    ).shareValue();

    final message$ = submitController.stream
        .withLatestFrom(
          Rx.combineLatest2(
            currentPasswordError$,
            newPasswordError$,
            (currentError, newError) => currentError == null && newError == null,
          ),
          (_, bool isValid) => isValid,
        )
        .where((isValid) => isValid)
        .withLatestFrom(
          Rx.combineLatest2(
            currentPasswordController.stream,
            newPasswordController.stream,
            (current, newPass) => (current: current, newPass: newPass),
          ),
          (_, data) => data,
        )
        .exhaustMap((data) => _changePassword(
              apiService,
              data.current,
              data.newPass,
              isLoadingController,
            ))
        .publish();

    return ChangePasswordBloc._(
      dispose: DisposeBag([
        currentPasswordController,
        newPasswordController,
        submitController,
        isLoadingController,
        message$.connect(),
      ]).dispose,
      submit: () => submitController.add(null),
      currentPasswordChanged: currentPasswordController.add,
      newPasswordChanged: newPasswordController.add,
      message$: message$,
      currentPasswordError$: currentPasswordError$,
      newPasswordError$: newPasswordError$,
      isLoading$: isLoadingController,
    );
  }

  static String? _validateCurrentPassword(String password) {
    if (password.isEmpty) return 'Current password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? _validateNewPassword(String currentPassword, String newPassword) {
    if (newPassword.isEmpty) return 'New password is required';
    if (newPassword.length < 6) return 'New password must be at least 6 characters';
    if (currentPassword == newPassword) {
      return 'New password must be different from current password';
    }
    return null;
  }

  static Stream<ChangePasswordMessage> _changePassword(
    ApiService apiService,
    String currentPassword,
    String newPassword,
    BehaviorSubject<bool> isLoadingController,
  ) async* {
    debugPrint('[ChangePasswordBloc] Changing password...');
    isLoadingController.add(true);

    try {
      await apiService.changePassword({
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      isLoadingController.add(false);
      yield ChangePasswordSuccessMessage();

    } catch (e) {
      debugPrint('[ChangePasswordBloc] Error: $e');
      isLoadingController.add(false);
      
      String errorMessage = 'Failed to change password';
      if (e.toString().contains('current_password') || 
          e.toString().contains('Current password')) {
        errorMessage = 'Current password is incorrect';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split(':').last.trim();
      }
      
      yield ChangePasswordErrorMessage(errorMessage);
    }
  }
}

abstract class ChangePasswordMessage {}

class ChangePasswordSuccessMessage extends ChangePasswordMessage {}

class ChangePasswordErrorMessage extends ChangePasswordMessage {
  final String message;
  ChangePasswordErrorMessage(this.message);
}