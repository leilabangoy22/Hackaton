// lib/features/auth/user/presentation/home/home_bloc.dart

import 'dart:async';
import 'dart:io';
import 'package:disposebag/disposebag.dart';
import 'package:fdr/features/auth/data/auth_state.dart';
import 'package:fdr/features/auth/data/user_and_token.dart';
import 'package:fdr/features/utils/type_defs.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';

import 'home_message.dart';

class HomeBloc extends DisposeCallbackBaseBloc {
  final Function0<void> changeAvatar;
  final Function0<void> logout;

  final ValueStream<AuthenticationState> authState$;
  final Stream<HomeMessage> message$;
  final ValueStream<bool> isUploading$;

  final ApiService _apiService;
  final BehaviorSubject<AuthenticationState> _authStateController;

  HomeBloc._({
    required this.changeAvatar,
    required this.message$,
    required this.logout,
    required this.authState$,
    required this.isUploading$,
    required ApiService apiService, 
    required BehaviorSubject<AuthenticationState>
    authStateController, 
    required VoidCallback dispose,
  }) : _apiService = apiService,
       _authStateController = authStateController,
       super(dispose);

  factory HomeBloc(
    ApiService apiService,
    AuthenticationState initialAuthState,
  ) {
    final changeAvatarS = PublishSubject<void>();
    final logoutS = PublishSubject<void>();
    final isUploadingController = BehaviorSubject<bool>.seeded(false);
    final authStateController = BehaviorSubject<AuthenticationState>.seeded(
      initialAuthState,
    );

    final logoutMessage$ = logoutS.exhaustMap(
      (_) => Stream.fromFuture(_performLogout(apiService)).map(
        (success) => success
            ? LogoutSuccessMessage()
            : LogoutErrorMessage('Logout failed'),
      ),
    );

    final imagePicker = ImagePicker();
    final updateAvatarMessage$ = changeAvatarS
        .switchMap(
          (_) => Stream.fromFuture(
            imagePicker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 720.0,
              maxHeight: 720.0,
            ),
          ),
        )
        .map((file) => file == null ? null : File(file.path))
        .whereType<File>()
        .distinct()
        .switchMap(
          (file) =>
              Stream.fromFuture(_performAvatarUpload(file, authStateController))
                  .doOnListen(() => isUploadingController.add(true))
                  .doOnDone(() => isUploadingController.add(false))
                  .doOnCancel(() => isUploadingController.add(false))
                  .map(
                    (success) => success
                        ? UpdateAvatarSuccessMessage()
                        : UpdateAvatarErrorMessage('Upload failed'),
                  ),
        );

    final message$ = Rx.merge<HomeMessage>([
      logoutMessage$,
      updateAvatarMessage$,
    ]).publish();

    return HomeBloc._(
      changeAvatar: () => changeAvatarS.add(null),
      logout: () => logoutS.add(null),
      authState$: authStateController.shareValue(),
      isUploading$: isUploadingController.shareValue(),
      apiService: apiService,
      authStateController: authStateController,
      dispose: DisposeBag([
        message$.connect(),
        changeAvatarS,
        logoutS,
        isUploadingController,
        authStateController,
      ]).dispose,
      message$: message$,
    );
  }

  static Future<bool> _performLogout(ApiService apiService) async {
    try {
      debugPrint('[HomeBloc] Attempting logout via API...');
      await apiService.logout();
      debugPrint('[HomeBloc] Logout successful');
      return true;
    } catch (e) {
      debugPrint('[HomeBloc] Logout error: $e');
      return false;
    }
  }

  static Future<bool> _performAvatarUpload(
    File imageFile,
    BehaviorSubject<AuthenticationState> authStateController,
  ) async {
    try {
      debugPrint('[HomeBloc] Simulating avatar upload...');

      await Future.delayed(const Duration(seconds: 2));

      final currentState = authStateController.value;
      if (currentState is AuthenticatedState &&
          currentState.userAndToken != null) {
        final currentUser = currentState.userAndToken!.user;
        final updatedUser = currentUser.copyWith(imageUrl: imageFile.path);

        final updatedState = AuthenticatedState(
          userAndToken: UserAndToken(
            user: updatedUser,
            token: currentState.userAndToken!.token,
          ),
        );

        authStateController.add(updatedState);
        debugPrint('[HomeBloc] Avatar updated locally');
      }

      return true;
    } catch (e) {
      debugPrint('[HomeBloc] Avatar upload error: $e');
      return false;
    }
  }

  void updateAuthState(AuthenticationState newState) {
    _authStateController.add(newState);
  }

  User? get currentUser {
    final state = _authStateController.value;
    if (state is AuthenticatedState) {
      return state.userAndToken?.user;
    }
    return null;
  }
}
