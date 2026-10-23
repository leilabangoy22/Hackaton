import 'package:fdr/features/auth/auth_presentation/reset_password/send_email/send_email_bloc.dart';
import 'package:fdr/features/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';

class SendEmailPage extends StatefulWidget {
  final VoidCallback toggle;

  const SendEmailPage({super.key, required this.toggle});

  @override
  State<SendEmailPage> createState() => _SendEmailPageState();
}

class _SendEmailPageState extends State<SendEmailPage>
    with SingleTickerProviderStateMixin, DisposeBagMixin {
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

    final bloc = BlocProvider.of<SendEmailBloc>(context);
    listen ??= [
      bloc.message$
          .map(_getMessageString)
          .listen(context.showSnackBar)
          .disposedBy(bag),
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
    super.dispose();
  }

  Widget _buildEmailTextField(SendEmailBloc bloc, ThemeData theme) {
    return StreamBuilder<String?>(
      stream: bloc.emailError$,
      builder: (context, snapshot) {
        return TextField(
          autocorrect: true,
          onChanged: bloc.submitEmail,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            bloc.submitEmail('email');
          },
          decoration: InputDecoration(
            hintText: 'Email Address',
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
              borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          maxLines: 1,
          autofocus: true,
          style: const TextStyle(fontSize: 16.0),
        );
      },
    );
  }

  // Helper widget for the custom logo
  Widget _buildLogo(ThemeData theme) {
    return RichText(
      textAlign: TextAlign.center,
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
    );
  }

  // Helper widget for the submit button
  Widget _buildSubmitButton(SendEmailBloc bloc, ThemeData theme) {
    return StreamBuilder<bool>(
      stream: bloc.isLoading$,
      builder: (context, snapshot) {
        final isLoading = snapshot.data ?? false;
        return SizedBox(
          height: 54.0,
          child: ElevatedButton(
            onPressed: isLoading ? null : () {
              final currentEmail = _getCurrentEmail(bloc);
              if (currentEmail != null && currentEmail.isNotEmpty) {
                bloc.submitEmail(currentEmail);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email address')),
                );
              }
            },
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
                    'Send Reset Link',
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

  String? _getCurrentEmail(SendEmailBloc bloc) {
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<SendEmailBloc>(context);
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
                'Reset Password',
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
                'Enter the email address associated with your account to receive a reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 40),
              // Email field
              _buildEmailTextField(bloc, theme),
              const SizedBox(height: 32),
              // Send button
              _buildSubmitButton(bloc, theme),
              // Loading indicator 
              StreamBuilder<bool>(
                stream: bloc.isLoading$,
                builder: (context, snapshot) {
                  final isLoading = snapshot.data ?? false;
                  return AnimatedOpacity(
                    opacity: isLoading ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Sending reset link...',
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
                    'Already have a token? ',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  InkWell(
                    onTap: widget.toggle,
                    child: Text(
                      'Reset Password',
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

  static String _getMessageString(SendEmailMessage msg) {
    return switch (msg) {
      SendEmailSuccessMessage() => 'Reset email sent successfully! Check your inbox.',
      SendEmailErrorMessage() => msg.message,
      SendEmailMessage() => throw UnimplementedError(),
    };
  }
}