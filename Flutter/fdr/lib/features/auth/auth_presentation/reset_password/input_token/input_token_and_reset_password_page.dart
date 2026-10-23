import 'package:fdr/features/auth/auth_presentation/reset_password/input_token/input_token_and_reset_password_bloc.dart';
import 'package:fdr/features/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';
import 'package:rxdart_ext/rxdart_ext.dart';

class InputTokenAndResetPasswordPage extends StatefulWidget {
  final VoidCallback toggle;

  const InputTokenAndResetPasswordPage({super.key, required this.toggle});

  @override
  State<InputTokenAndResetPasswordPage> createState() =>
      _InputTokenAndResetPasswordPageState();
}

class _InputTokenAndResetPasswordPageState
    extends State<InputTokenAndResetPasswordPage>
    with
        SingleTickerProviderStateMixin<InputTokenAndResetPasswordPage>,
        DisposeBagMixin {
  final tokenFocusNode = FocusNode();
  final newPasswordFocusNode = FocusNode();
  final confirmPasswordFocusNode = FocusNode();

  late final AnimationController fadeController;
  late final Animation<double> fadeAnim;
  Object? listen;

  @override
  void initState() {
    super.initState();

    fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        curve: Curves.fastOutSlowIn,
        parent: fadeController,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bloc = BlocProvider.of<InputTokenAndResetPasswordBloc>(context);

    listen ??= [
      bloc.message$
          .flatMap((message) async* {
        context.showSnackBar(_getMessageString(message));
        await delay(1000);
        yield null;

        if (message is ResetPasswordSuccessMessage) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }).collect().disposedBy(bag),
      bloc.isLoading$.listen((isLoading) {
        if (isLoading) {
          fadeController.forward();
        } else {
          fadeController.reverse();
        }
      }).disposedBy(bag),
    ];
  }

  @override
  void dispose() {
    fadeController.dispose();
    tokenFocusNode.dispose();
    newPasswordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Widget _buildLogo(ThemeData theme) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'FD',
              style: theme.textTheme.headlineLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontSize: 48,
              ),
            ),
            TextSpan(
              text: 'R',
              style: theme.textTheme.headlineLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                fontSize: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required Stream<String?> errorStream,
    required ValueChanged<String> onChanged,
    required TextInputAction textInputAction,
    required FocusNode focusNode,
    required String hintText,
    FocusNode? nextFocusNode,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool autofocus = false,
    VoidCallback? onSubmitted,
  }) {
    final theme = Theme.of(context);

    return StreamBuilder<String?>(
      stream: errorStream,
      builder: (context, snapshot) {
        return TextField(
          focusNode: focusNode,
          autocorrect: false,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: snapshot.data,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: keyboardType,
          maxLines: 1,
          autofocus: autofocus,
          onChanged: onChanged,
          textInputAction: textInputAction,
          onSubmitted: (_) {
            if (nextFocusNode != null) {
              FocusScope.of(context).requestFocus(nextFocusNode);
            } else {
              FocusScope.of(context).unfocus();
              onSubmitted?.call();
            }
          },
          style: const TextStyle(fontSize: 16.0),
        );
      },
    );
  }

  // Helper widget for the submit button
  Widget _buildSubmitButton(InputTokenAndResetPasswordBloc bloc, ThemeData theme) {
    return StreamBuilder<bool>(
      stream: bloc.isLoading$,
      builder: (context, snapshot) {
        final isLoading = snapshot.data ?? false;
        return SizedBox(
          height: 54.0,
          child: ElevatedButton(
            onPressed: isLoading ? null : bloc.submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resetPasswordBloc = BlocProvider.of<InputTokenAndResetPasswordBloc>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              // Logo
              _buildLogo(theme),
              const SizedBox(height: 16),
              // Sub-title
              Text(
                'New Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              // Instructions
              Text(
                'Enter the token sent to your email and your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 40),
              // Token field
              _buildTextField(
                errorStream: resetPasswordBloc.tokenError$,
                onChanged: resetPasswordBloc.tokenChanged,
                textInputAction: TextInputAction.next,
                focusNode: tokenFocusNode,
                nextFocusNode: newPasswordFocusNode,
                hintText: 'Verification Token',
                keyboardType: TextInputType.text,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // New Password field
              _buildTextField(
                errorStream: resetPasswordBloc.newPasswordError$,
                onChanged: resetPasswordBloc.newPasswordChanged,
                textInputAction: TextInputAction.next,
                focusNode: newPasswordFocusNode,
                nextFocusNode: confirmPasswordFocusNode,
                hintText: 'New Password',
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: 16),
              // Confirm Password field
              _buildTextField(
                errorStream: resetPasswordBloc.confirmPasswordError$,
                onChanged: resetPasswordBloc.confirmPasswordChanged,
                textInputAction: TextInputAction.done,
                focusNode: confirmPasswordFocusNode,
                hintText: 'Confirm New Password',
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                onSubmitted: resetPasswordBloc.submit,
              ),
              const SizedBox(height: 32),
              // Submit button
              _buildSubmitButton(resetPasswordBloc, theme),
              // Loading indicator text
              StreamBuilder<bool>(
                stream: resetPasswordBloc.isLoading$,
                builder: (context, snapshot) {
                  final isLoading = snapshot.data ?? false;
                  return AnimatedOpacity(
                    opacity: isLoading ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Resetting password...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Toggle link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Need a token? ',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  InkWell(
                    onTap: widget.toggle,
                    child: Text(
                      'Request Email',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _getMessageString(ResetPasswordMessage msg) {
    return switch (msg) {
      ResetPasswordSuccessMessage() => 'Password reset successfully! You can now login with your new password.',
      ResetPasswordErrorMessage() => msg.message,
      ResetPasswordMessage() => throw UnimplementedError(),
    };
  }
}