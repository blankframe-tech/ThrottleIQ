import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  bool _loading = false;
  String? _usernameError;
  int _step = 0; // 0 = name, 1 = bike

  @override
  void initState() {
    super.initState();
    final email = ref.read(currentUserProvider)?.email;
    if (email != null) {
      _usernameCtrl.text = ProfileRepository().suggestUsernameBase(email);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _ccCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _usernameError = null;
    });

    try {
      if (_step == 0) {
        // Step 1: Save name + claim @handle (prefilled from email, but
        // editable — "offer them to create username" per spec — while
        // AuthNotifier._ensureUsername covers anyone who skips this screen
        // entirely, so every rider ends up with one regardless).
        final notifier = ref.read(authNotifierProvider.notifier);
        try {
          await notifier.claimUsername(_usernameCtrl.text.trim());
        } on UsernameTakenException {
          setState(() {
            _loading = false;
            _usernameError = 'That username is taken — try another.';
          });
          return;
        } on InvalidUsernameException catch (e) {
          setState(() {
            _loading = false;
            _usernameError = e.toString();
          });
          return;
        }
        await notifier.updateDisplayName(_nameCtrl.text.trim());
        setState(() {
          _step = 1;
          _loading = false;
        });
      } else {
        // Step 2: Add first bike
        await ref.read(garageProvider.notifier).addBike(
              brand: _brandCtrl.text.trim(),
              model: _modelCtrl.text.trim(),
              year: int.tryParse(_yearCtrl.text),
              cc: int.tryParse(_ccCtrl.text),
            );

        if (mounted) {
          context.go('/home/record');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _previous() {
    setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(
                  _step == 0 ? Icons.person : Icons.two_wheeler,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _step == 0 ? "What's your name?" : "Let's add your first bike",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 0
                      ? 'So we can personalize your experience'
                      : 'We use this to track rides and maintenance per bike',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),
                if (_step == 0) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'John Doe',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Username *',
                      prefixText: '@',
                      hintText: 'yourhandle',
                      errorText: _usernameError,
                      helperText: 'Your public handle — you can change this later.',
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value)) {
                        return '3-20 characters: letters, numbers, underscore';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _brandCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Brand *',
                      hintText: 'Yamaha, Honda, Bajaj...',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Model *',
                      hintText: 'FZ-S, CB300R, Pulsar...',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _yearCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Year', hintText: '2023'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _ccCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration:
                              const InputDecoration(labelText: 'Engine CC', hintText: '150'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_step == 0 ? 'Continue' : 'Get Started'),
                ),
                const SizedBox(height: 12),
                if (_step > 0)
                  TextButton(
                    onPressed: _loading ? null : _previous,
                    child: const Text('Back',
                        style: TextStyle(color: AppColors.textTertiary)),
                  ),
                TextButton(
                  onPressed: () => context.go('/home/record'),
                  child: const Text('Skip for now',
                      style: TextStyle(color: AppColors.textTertiary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
