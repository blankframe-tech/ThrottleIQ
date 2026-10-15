import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../providers/auth_provider.dart';
import '../../../../core/i18n/l10n_context.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).register(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
    _showErrorIfAny();
  }

  Future<void> _googleSignUp() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    _showErrorIfAny();
  }

  void _showErrorIfAny() {
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(err, context.l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(context.l10n.createAccount),
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  context.l10n.joinThrottleiq,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.trackEveryRideRemember,
                  style: TextStyle(fontSize: 15, color: context.palette.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: InputDecoration(labelText: context.l10n.email, hintText: 'rider@example.com'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return context.l10n.emailRequired;
                    if (!v.contains('@')) return context.l10n.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.password,
                    hintText: context.l10n.n6Characters,
                    suffixIcon: IconButton(
                      tooltip: context.l10n.showPassword,
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          color: context.palette.textSecondary, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return context.l10n.min6Characters;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: InputDecoration(labelText: context.l10n.confirmPassword),
                  validator: (v) {
                    if (v != _passCtrl.text) return context.l10n.passwordsDoNotMatch;
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.l10n.createAccount),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: context.palette.textSecondary)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(context.l10n.orDivider,
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: context.palette.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: loading ? null : _googleSignUp,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(context.l10n.signUpWithGoogle),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.textPrimary,
                    side: BorderSide(color: context.palette.textPrimary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.l10n.alreadyHaveAccount,
                        style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text(context.l10n.signIn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
