import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/utils/validators.dart';
import 'package:summerschool/widgets/common/custom_button.dart';
import 'package:summerschool/widgets/common/custom_text_field.dart';
import 'package:summerschool/services/local_storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    // Persist remember-me preference and saved email
    final storage = context.read<LocalStorageService>();
    if (success) {
      if (_rememberMe) {
        await storage.setRememberMe(true);
        await storage.setSavedEmail(_emailController.text);
      } else {
        await storage.setRememberMe(false);
        await storage.setSavedEmail(null);
      }
    }

    if (success) {
      final nextRoute = authProvider.isManager
          ? AppRoutes.managerHome
          : AppRoutes.membersHome;
      Navigator.pushNamedAndRemoveUntil(context, nextRoute, (_) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(authProvider.errorMessage ?? 'Login failed')),
    );
  }

  // Removed forgot password flow per request

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final storage = context.read<LocalStorageService>();
      final remember = await storage.getRememberMe();
      final savedEmail = remember ? await storage.getSavedEmail() : null;
      if (!mounted) return;
      setState(() {
        _rememberMe = remember;
        if (savedEmail != null) {
          _emailController.text = savedEmail;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: IconButton.filledTonal(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 36),
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log in to continue to the management page',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          obscureText: _isPasswordHidden,
                          validator: Validators.password,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _isPasswordHidden = !_isPasswordHidden,
                              );
                            },
                            icon: Icon(
                              _isPasswordHidden
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) {
                                setState(() => _rememberMe = v ?? false);
                              },
                            ),
                            const SizedBox(width: 6),
                            const Expanded(child: Text('Remember me')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomButton(
                          label: 'Login',
                          isLoading: authProvider.isLoading,
                          onPressed: _login,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.adminLogin);
                          },
                          icon: const Icon(Icons.admin_panel_settings_rounded),
                          label: const Text('Admin Panel (Local)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0),
          ],
        ),
      ),
    );
  }
}
