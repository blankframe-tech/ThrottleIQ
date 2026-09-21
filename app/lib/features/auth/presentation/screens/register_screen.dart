import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../providers/auth_provider.dart';

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
        SnackBar(content: Text(mapFirebaseAuthError(err))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          tooltip: 'Back',
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
                  'Join ThrottleIQ',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track every ride, remember every mile',
                  style: TextStyle(fontSize: 15, color: context.palette.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'rider@example.com'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '6+ characters',
                    suffixIcon: IconButton(
                      tooltip: 'Show password',
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          color: context.palette.textSecondary, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Passwords do not match';
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
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: context.palette.textSecondary)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: context.palette.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: loading ? null : _googleSignUp,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Sign up with Google'),
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
                    Text('Already have an account? ',
                        style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: const Text('Sign In'),
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
