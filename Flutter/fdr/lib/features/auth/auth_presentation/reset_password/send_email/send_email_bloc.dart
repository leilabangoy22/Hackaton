// lib/features/auth/auth_presentation/reset_password/send_email/send_email_bloc.dart
import 'dart:async';
import 'package:disposebag/disposebag.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:rxdart/rxdart.dart';

class SendEmailBloc extends DisposeCallbackBaseBloc {
  final Function(String) submitEmail;
  final Stream<String?> emailError$;
  final Stream<bool> isLoading$;
  final Stream<SendEmailMessage> message$;

  SendEmailBloc._({
    required this.submitEmail,
    required this.emailError$,
    required this.isLoading$,
    required this.message$,
    required Function() dispose,
  }) : super(dispose);

  factory SendEmailBloc(ApiService apiService) {
    final submitEmailController = PublishSubject<String>();
    final isLoadingController = BehaviorSubject.seeded(false);

    final emailError$ = submitEmailController.stream
        .map((email) => _validateEmail(email))
        .shareValue();

    final message$ = submitEmailController
        .withLatestFrom(emailError$, (email, error) => (email, error))
        .where((tuple) => tuple.$2 == null)
        .map((tuple) => tuple.$1)
        .exhaustMap((email) => _sendResetPasswordEmail(apiService, email, isLoadingController))
        .publish();

    return SendEmailBloc._(
      submitEmail: submitEmailController.add,
      emailError$: emailError$,
      isLoading$: isLoadingController,
      message$: message$,
      dispose: DisposeBag([
        submitEmailController,
        isLoadingController,
        message$.connect(),
      ]).dispose,
    );
  }

  static String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email cannot be empty';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static Stream<SendEmailMessage> _sendResetPasswordEmail(
    ApiService apiService,
    String email,
    BehaviorSubject<bool> isLoadingController,
  ) async* {
    isLoadingController.add(true);
    
    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      

      isLoadingController.add(false);
      yield SendEmailSuccessMessage();
      
    } catch (e) {
      isLoadingController.add(false);
      yield SendEmailErrorMessage('Failed to send reset email: ${e.toString()}');
    }
  }
}

abstract class SendEmailMessage {}

class SendEmailSuccessMessage extends SendEmailMessage {}

class SendEmailErrorMessage extends SendEmailMessage {
  final String message;
  SendEmailErrorMessage(this.message);
}