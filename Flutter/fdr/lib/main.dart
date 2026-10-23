import 'package:fdr/app_routes.dart';
import 'package:fdr/services/api_service.dart';
import 'package:fdr/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fdr/features/auth/login/login_bloc.dart';

void main() {
  setupServices();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => ApiService(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LoginBloc>(
            create: (context) =>
                LoginBloc(RepositoryProvider.of<ApiService>(context)),
          ),
        ],
        child: MaterialApp(
          title: 'FDR',
          initialRoute: AppRoutes.initialRoute,
          onGenerateRoute: AppRouter.generateRoute,
          theme: ThemeData(primarySwatch: Colors.blue),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}