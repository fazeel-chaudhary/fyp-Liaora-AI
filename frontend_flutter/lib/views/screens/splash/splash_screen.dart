import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:frontend_flutter/utils/navigation/navigator.dart';
import 'package:frontend_flutter/views/reusables/app_icon.dart';
import 'package:frontend_flutter/views/reusables/loading_anim.dart';
import 'package:frontend_flutter/views/screens/auth/auth_screen.dart';
import 'package:frontend_flutter/views/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await Future.delayed(const Duration(seconds: 3));

    // For web sessions, always require explicit sign-in instead of silent token restore.
    if (kIsWeb) {
      if (mounted) {
        Navigator.of(context).pushReplacement(elegantRoute(const AuthScreen()));
      }
      return;
    }

    // Check authentication
    final isAuthenticated = await authProvider.tryAutoLogin();

    if (mounted) {
      if (isAuthenticated) {
        Navigator.of(context).pushReplacement(elegantRoute(const HomeScreen()));
      } else {
        Navigator.of(context).pushReplacement(elegantRoute(const AuthScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Spacer(flex: 2),

          // App Icon
          AppIcon(),

          const SizedBox(height: 24),

          // App Name
          Text(
            'Liora',
            style: TextStyle(
              fontSize: SizeConfig.height * 0.06,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -2.0,
            ),
          ),

          const Spacer(flex: 2),

          // Loading
          const LoadingAnim(),

          const Spacer(flex: 1),
        ],
      ),
    );
  }
}
