import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'core/config/router_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/splash/presentation/pages/splash_screen.dart';
import 'features/projects/data/services/openshot_initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  // Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    debug: true,
  );

  // Initialize OpenShot service
  final openShotInit = OpenShotInitializationService();
  try {
    await openShotInit.initialize();
  } catch (e) {
    print(
        'Warning: OpenShot initialization failed. Video processing will be disabled: $e');
  }

  // Initialize repositories AFTER Firebase
  final authRepository = AuthRepositoryImpl();

  runApp(MyApp(authRepository: authRepository, openShotInit: openShotInit));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final OpenShotInitializationService openShotInit;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.openShotInit,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final bloc = AuthBloc(
              authRepository: authRepository,
            );
            // Check auth status when app starts
            bloc.add(const CheckAuthStatus());
            return bloc;
          },
        ),
      ],
      child: PlatformApp(
        authRepository: authRepository,
        openShotInit: openShotInit,
      ),
    );
  }
}

class PlatformApp extends StatelessWidget {
  final AuthRepository authRepository;
  final OpenShotInitializationService openShotInit;

  const PlatformApp({
    super.key,
    required this.authRepository,
    required this.openShotInit,
  });

  @override
  Widget build(BuildContext context) {
    // For this app, we'll use Cupertino styling for specific pages
    // but keep Material as the base for the video editor
    return MaterialApp.router(
      title: 'CookCut',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        // Wrap the app with a platform-aware styling context
        return Theme(
          data: Theme.of(context).copyWith(
            // Use Cupertino-style scrolling physics by default
            scrollbarTheme: const ScrollbarThemeData(
              thickness: MaterialStatePropertyAll(8.0),
              thumbVisibility: MaterialStatePropertyAll(true),
            ),
            // Use iOS-style bouncing scroll physics
            platform: TargetPlatform.iOS,
          ),
          child: child!,
        );
      },
    );
  }
}
