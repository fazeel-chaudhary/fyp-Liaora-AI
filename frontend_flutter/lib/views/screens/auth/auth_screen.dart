import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:frontend_flutter/utils/navigation/navigator.dart';
import 'package:frontend_flutter/views/reusables/app_icon.dart';
import 'package:frontend_flutter/views/reusables/loading_anim.dart';
import 'package:frontend_flutter/views/reusables/textfield.dart';
import 'package:frontend_flutter/views/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider authProvider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (authProvider.isLogin) {
      await authProvider.login(email, password, context);
      if (!mounted) return;
      if (authProvider.isLoggedIn) {
        SnackbarHelper.show(context, "Login successful!", isError: false);

        Navigator.of(context).pushReplacement(elegantRoute(const HomeScreen()));
      }
    } else {
      await authProvider.signup(email, password, username, context);
      if (!mounted) return;

      SnackbarHelper.show(
        context,
        "Signup complete! Please sign in.",
        isError: false,
      );

      authProvider.toggleAuthMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) => Scaffold(
        extendBodyBehindAppBar: true,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      height:
                          SizeConfig.height -
                          MediaQuery.of(context).padding.top,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Spacer(flex: 1),

                            // Hero Section
                            Column(
                              children: [
                                const AppIcon(),
                                SizedBox(height: SizeConfig.height * 0.02),
                                Text(
                                  authProvider.isLogin
                                      ? "Welcome\nBack"
                                      : "Create\nAccount",
                                  style: TextStyle(
                                    fontSize: SizeConfig.height * 0.02,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: SizeConfig.height * 0.02),
                                Text(
                                  authProvider.isLogin
                                      ? "Sign in to continue your AI journey"
                                      : "Join Liora and discover your perfect AI companion",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),

                            SizedBox(height: SizeConfig.height * 0.04),

                            // Form Fields
                            Column(
                              children: [
                                if (!authProvider.isLogin) ...[
                                  ModernTextField(
                                    controller: _usernameController,
                                    label: "Username",
                                    icon: Icons.person_outline_rounded,
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? "Enter a username"
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                ModernTextField(
                                  controller: _emailController,
                                  label: "Email",
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) =>
                                      value == null || !value.contains("@")
                                      ? "Enter a valid email"
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                ModernTextField(
                                  controller: _passwordController,
                                  label: "Password",
                                  icon: Icons.lock_outline_rounded,
                                  isObscured: true,
                                  validator: (value) =>
                                      value == null || value.length < 6
                                      ? "Password must be at least 6 characters"
                                      : null,
                                ),
                              ],
                            ),

                            SizedBox(height: SizeConfig.height * 0.04),

                            // Action Buttons
                            Column(
                              children: [
                                authProvider.isLoading
                                    ? Container(
                                        width: double.infinity,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: const Center(
                                          child: LoadingAnim(),
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () => _submit(authProvider),
                                        child: Container(
                                          width: double.infinity,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                theme.colorScheme.primary,
                                                theme.colorScheme.primary
                                                    .withValues(alpha: 0.8),
                                              ],
                                            ),
                                            border: Border.all(
                                              width: 1.0,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              authProvider.isLogin
                                                  ? "Sign In"
                                                  : "Create Account",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 24),

                                // Toggle Auth Mode
                                GestureDetector(
                                  onTap: () {
                                    authProvider.toggleAuthMode();
                                    _usernameController.clear();
                                    _emailController.clear();
                                    _passwordController.clear();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      authProvider.isLogin
                                          ? "Don't have an account? Sign up"
                                          : "Already have an account? Sign in",
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: 15,
                                        letterSpacing: -0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(flex: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
