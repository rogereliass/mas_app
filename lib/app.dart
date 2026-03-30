import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/theme_config.dart';
import 'core/config/theme_provider.dart';
import 'core/constants/app_colors.dart';
import 'core/services/connectivity_service.dart';
import 'routing/app_router.dart';
import 'routing/navigation_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isOnline;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;
    _subscription = ConnectivityService.instance.statusStream.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Scout Digital Library',
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: AppRouter.startup,
          routes: AppRouter.routes,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();

            final mediaQuery = MediaQuery.of(context);

            final newMediaQuery = !_isOnline
                ? mediaQuery.copyWith(
                    padding: mediaQuery.padding.copyWith(
                      top: mediaQuery.padding.top + 40,
                    ),
                  )
                : mediaQuery;

            return MediaQuery(
              data: newMediaQuery,
              child: Stack(
                children: [
                  child,
                  if (!_isOnline)
                    Positioned(
                      top: mediaQuery.padding.top,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 40,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.warning.withValues(alpha: 0.3)
                              : AppColors.warning,
                          child: Text(
                            'Offline mode',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
