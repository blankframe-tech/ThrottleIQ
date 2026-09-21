import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../providers/auth_provider.dart';
import '../../../../core/i18n/l10n_context.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
    _showErrorIfAny();
  }

  Future<void> _googleSignIn() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    _showErrorIfAny();
  }

  void _showErrorIfAny() {
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(err))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const _ThrottleHeader(),
                const SizedBox(height: 40),
                _field(
                  controller: _emailCtrl,
                  label: context.l10n.email,
                  hint: 'rider@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return context.l10n.emailRequired;
                    if (!v.contains('@')) return context.l10n.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _passCtrl,
                  label: context.l10n.password,
                  hint: '••••••••',
                  obscure: _obscure,
                  suffix: IconButton(
                    tooltip: context.l10n.showPassword,
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: context.palette.textSecondary, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return context.l10n.passwordTooShort;
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
                      : Text(context.l10n.signIn),
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
                  onPressed: loading ? null : _googleSignIn,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(context.l10n.continueWithGoogle),
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
                    Text(context.l10n.noAccountPrompt,
                        style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.go('/auth/register'),
                      child: Text(context.l10n.signUp),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
      validator: validator,
    );
  }
}

class _ThrottleHeader extends StatelessWidget {
  const _ThrottleHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.welcomeBack,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, color: context.palette.textPrimary)),
        const SizedBox(height: 6),
        Text(context.l10n.signInSubtitle,
            style: TextStyle(fontSize: 15, color: context.palette.textSecondary)),
      ],
    );
  }
}
