import 'package:fdr/features/auth/auth_presentation/change_password/change_password_bloc.dart';
import 'package:fdr/features/widgets/password_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';

class ChangePasswordBottomSheet extends StatefulWidget {
  const ChangePasswordBottomSheet({super.key});

  @override
  State<ChangePasswordBottomSheet> createState() =>
      _ChangePasswordBottomSheetState();
}

class _ChangePasswordBottomSheetState extends State<ChangePasswordBottomSheet>
    with DisposeBagMixin {
  final currentPasswordFocusNode = FocusNode();
  final newPasswordFocusNode = FocusNode();
  Object? listen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bloc = BlocProvider.of<ChangePasswordBloc>(context);

    listen ??= bloc.message$
        .listen((message) {
          if (message is ChangePasswordSuccessMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password changed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          } else if (message is ChangePasswordErrorMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        })
        .disposedBy(bag);
  }

  @override
  void dispose() {
    currentPasswordFocusNode.dispose();
    newPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final changePasswordBloc = BlocProvider.of<ChangePasswordBloc>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<String?>(
                stream: changePasswordBloc.currentPasswordError$,
                builder: (context, snapshot) {
                  return PasswordTextField(
                    errorText: snapshot.data,
                    onChanged: changePasswordBloc.currentPasswordChanged,
                    labelText: 'Current Password',
                    onSubmitted: () {
                      FocusScope.of(context).requestFocus(newPasswordFocusNode);
                    },
                    textInputAction: TextInputAction.next,
                    focusNode: currentPasswordFocusNode,
                    autofocus: true,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<String?>(
                stream: changePasswordBloc.newPasswordError$,
                builder: (context, snapshot) {
                  return PasswordTextField(
                    errorText: snapshot.data,
                    onChanged: changePasswordBloc.newPasswordChanged,
                    labelText: 'New Password',
                    focusNode: newPasswordFocusNode,
                    onSubmitted: () {
                      FocusScope.of(context).unfocus();
                      changePasswordBloc.submit();
                    },
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(32.0),
              child: StreamBuilder<bool>(
                stream: changePasswordBloc.isLoading$,
                builder: (context, snapshot) {
                  final isLoading = snapshot.data ?? false;

                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      elevation: 4,
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      changePasswordBloc.submit();
                    },
                    child: const Text(
                      'Change Password',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
