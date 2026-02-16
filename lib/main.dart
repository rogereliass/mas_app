import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:masapp/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/theme_provider.dart';
import 'library/logic/library_provider.dart';
import 'auth/logic/auth_provider.dart';
import 'home/pages/admin_approval/logic/admin_provider.dart';
import 'home/pages/user_management/logic/user_management_provider.dart';
import 'home/pages/season_management/logic/season_management_provider.dart';
import 'offline/offline_storage.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env asset file
  await dotenv.load(fileName: '.env');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize offline storage service
  await OfflineStorageService.initialize();

  runApp(
    // Wrap app with providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        
        // AdminProvider depends on AuthProvider for role-based scoping
        ChangeNotifierProxyProvider<AuthProvider, AdminProvider>(
          create: (context) => AdminProvider(
            authProvider: context.read<AuthProvider>(),
          ),
          update: (context, auth, previous) =>
            previous ?? AdminProvider(authProvider: auth),
        ),
        
        // UserManagementProvider depends on AuthProvider for role-based scoping
        ChangeNotifierProxyProvider<AuthProvider, UserManagementProvider>(
          create: (context) => UserManagementProvider(
            authProvider: context.read<AuthProvider>(),
          ),
          update: (context, auth, previous) =>
            previous ?? UserManagementProvider(authProvider: auth),
        ),
        
        // LibraryProvider depends on AuthProvider for role-based filtering
        ChangeNotifierProxyProvider<AuthProvider, LibraryProvider>(
          create: (context) => LibraryProvider(
            authProvider: context.read<AuthProvider>(),
          ),
          update: (context, auth, previous) {
            // Reuse existing provider to preserve state, just update auth reference
            if (previous != null) {
              return previous;
            }
            return LibraryProvider(authProvider: auth);
          },
        ),
        
        ChangeNotifierProvider(create: (_) => SeasonManagementProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

