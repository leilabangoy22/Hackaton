import 'dart:async';

import 'package:fdr/features/auth/auth_presentation/reset_password/input_token/input_token_and_reset_password_bloc.dart';
import 'package:fdr/features/auth/auth_presentation/reset_password/input_token/input_token_and_reset_password_page.dart';
import 'package:fdr/features/auth/auth_presentation/reset_password/send_email/send_email_bloc.dart';
import 'package:fdr/features/auth/auth_presentation/reset_password/send_email/send_email_page.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';
import 'package:flutter_provider/flutter_provider.dart';
import 'package:rxdart_ext/rxdart_ext.dart';

class ResetPasswordPage extends StatefulWidget {
  static const routeName = '/reset_password_page';

  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin<ResetPasswordPage>, DisposeBagMixin {
  final requestEmailS = StreamController<void>(sync: true);
  late final StateStream<bool> requestEmail$;

  late final AnimationController animationController;
  late final Animation<Offset> slideInAnimation;
  late final Animation<Offset> slideOutAnimation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    slideInAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
        );

    slideOutAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
          CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
        );

    requestEmail$ =
        requestEmailS.stream
            .scan<bool>((acc, e, _) => !acc, true)
            .doOnData(
              (requestEmailPage) => requestEmailPage
                  ? animationController.reverse()
                  : animationController.forward(),
            )
            .publishState(true)
          ..connect().disposedBy(bag);
    requestEmailS.disposedBy(bag);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void onToggle() => requestEmailS.add(null);

  @override
  Widget build(BuildContext context) {
    final apiService = context.get<ApiService>();

    final sendEmailPage = BlocProvider<SendEmailBloc>(
      initBloc: (context) => SendEmailBloc(apiService),
      child: SendEmailPage(toggle: onToggle),
    );

    final resetPasswordPage = BlocProvider<InputTokenAndResetPasswordBloc>(
      initBloc: (context) => InputTokenAndResetPasswordBloc(apiService),
      child: InputTokenAndResetPasswordPage(toggle: onToggle),
    );

    return RxStreamBuilder<bool>(
      stream: requestEmail$,
      builder: (context, requestEmailPage) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: <Widget>[
              SlideTransition(
                position: slideOutAnimation,
                child: IgnorePointer(
                  ignoring: !requestEmailPage,
                  child: sendEmailPage,
                ),
              ),

              SlideTransition(
                position: slideInAnimation,
                child: IgnorePointer(
                  ignoring: requestEmailPage,
                  child: resetPasswordPage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
