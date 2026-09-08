import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/bike_catalog.dart';
import '../../../../shared/widgets/brand_model_field.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import 'onboarding_manifest.dart';
import 'onboarding_tour_provider.dart';
import '../widgets/onboarding_slide_page.dart';

/// Multi-step onboarding flow for new ThrottleIQ users.
///
/// ## Step structure
///
///   Step 0  — Name + @username (functional: persisted to Firebase Auth)
///   Step 1  — Add first bike (functional: persisted to SQLite + Firestore)
///   Steps 2+ — Feature-tour slides (informational, from [kOnboardingSlides])
///
/// ## Auto-updating
/// The tour slides are driven by [kOnboardingManifestVersion] and
/// [kOnboardingSlides] in `onboarding_manifest.dart`. Bumping the version
/// constant causes existing users who already completed the old tour to see
/// the new slides automatically on next launch.
///
/// ## Router contract
/// The router redirects any authenticated user with `displayName == null`
/// to `/auth/onboarding` (covering Steps 0–1). After Step 1 the display name
/// is set, so the redirect no longer fires; the screen self-manages Steps 2+
/// using [onboardingTourCompleteProvider] / [markOnboardingTourComplete].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.demoMode = false,
    this.initialSlide = 0,
  });

  final bool demoMode;
  final int initialSlide;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // ─── Functional step controllers ───────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  bool _loading = false;
  String? _usernameError;

  /// 0 = name/username form, 1 = add-bike form, 2+ = tour slide (index 2 → slide 0).
  int _step = 0;

  // ─── Tour PageView ──────────────────────────────────────────────────────────
  late final PageController _pageCtrl;

  /// Current tour slide index (0-based within [kOnboardingSlides]).
  int _tourSlide = 0;

  @override
  void initState() {
    super.initState();
    _step = widget.demoMode ? 2 : 0;
    _tourSlide = widget.initialSlide.clamp(0, kOnboardingSlides.length - 1);
    _pageCtrl = PageController(initialPage: _tourSlide);
    final email = ref.read(currentUserProvider)?.email;
    if (email != null) {
      _usernameCtrl.text = ProfileRepository().suggestUsernameBase(email);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _ccCtrl.dispose();
    super.dispose();
  }

  // ─── Functional step logic ──────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _usernameError = null;
    });

    try {
      if (_step == 0) {
        // Step 0: claim @handle + set display name
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
      } else if (_step == 1) {
        // Step 1: add first bike → then start the tour
        await ref.read(garageProvider.notifier).addBike(
              brand: _brandCtrl.text.trim(),
              model: _modelCtrl.text.trim(),
              year: int.tryParse(_yearCtrl.text),
              cc: int.tryParse(_ccCtrl.text),
            );
        if (mounted) {
          setState(() {
            _step = 2; // enter tour
            _tourSlide = 0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _previous() => setState(() => _step = 0);

  // ─── Tour navigation ────────────────────────────────────────────────────────

  Future<void> _skipTour() async {
    await markOnboardingTourComplete();
    if (!mounted) return;
    context.go('/home/record');
  }

  Future<void> _advanceTour() async {
    if (_tourSlide < kOnboardingSlides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      // Last slide — finish tour
      await _finishTour(navigateTo: '/home/record');
    }
  }

  /// "Show me" CTA: mark complete then jump to the slide's target route.
  Future<void> _showMeFor(int slideIndex) async {
    final route = kOnboardingSlides[slideIndex].showMeRoute;
    await _finishTour(navigateTo: route ?? '/home/record');
  }

  Future<void> _finishTour({required String navigateTo}) async {
    await markOnboardingTourComplete();
    if (!mounted) return;

    // If this is the profile slide, show the bio prompt sheet after navigating.
    final isProfile = kOnboardingSlides[_tourSlide].featureKey == 'profile';
    // Capture context-dependent objects before the async gap below.
    final router = GoRouter.of(context);
    // ignore: use_build_context_synchronously — mounted checked above and below.
    final ctx = context;

    router.go(navigateTo);

    if (isProfile) {
      // Small delay so the destination screen finishes mounting before the
      // bottom sheet opens on top of it.
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      EditProfileScreen.showBioPromptSheet(ctx);
    }
  }


  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Tour phase: drive the PageView.
    if (_step >= 2) {
      return _buildTour();
    }

    // Functional phase: name or bike form.
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

                // ── Progress indicator (step 0 / step 1) ──────────────────
                _SetupProgressBar(currentStep: _step),

                const SizedBox(height: 32),

                // ── Icon ─────────────────────────────────────────────────
                Icon(
                  _step == 0 ? Icons.person_outline : Icons.two_wheeler,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),

                // ── Heading ───────────────────────────────────────────────
                Text(
                  _step == 0 ? "What should we call you?" : "Add your first bike",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 0
                      ? 'Your name and @handle so the community can find you.'
                      : 'ThrottleIQ tracks rides and maintenance per bike.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 32),

                // ── Form fields ───────────────────────────────────────────
                if (_step == 0) ..._nameFields() else ..._bikeFields(),

                const SizedBox(height: 32),

                // ── Primary CTA ───────────────────────────────────────────
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_step == 0 ? 'Continue →' : 'Add bike & take the tour'),
                ),

                const SizedBox(height: 12),

                if (_step > 0)
                  TextButton(
                    onPressed: _loading ? null : _previous,
                    child: Text('← Back',
                        style: TextStyle(color: AppColors.textTertiary)),
                  ),

                // Skip links
                if (_step == 1)
                  TextButton(
                    onPressed: () async {
                      // Skip bike + entire tour
                      await markOnboardingTourComplete();
                      if (!mounted) return;
                      context.go('/home/record');
                    },
                    child: Text('Skip for now',
                        style: TextStyle(color: AppColors.textTertiary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Form field helpers ─────────────────────────────────────────────────────

  List<Widget> _nameFields() => [
        TextFormField(
          controller: _nameCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            hintText: 'e.g. Rahim Hossain',
          ),
          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _usernameCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Username *',
            prefixText: '@',
            hintText: 'yourhandle',
            errorText: _usernameError,
            helperText: 'Letters, numbers, underscore · 3–20 chars',
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
      ];

  List<Widget> _bikeFields() => [
        BrandModelAutocompleteField(
          controller: _brandCtrl,
          labelText: 'Brand *',
          hintText: 'Yamaha, Honda, Bajaj…',
          optionsBuilder: (_) => bikeCatalogBrands,
        ),
        const SizedBox(height: 12),
        BrandModelAutocompleteField(
          controller: _modelCtrl,
          labelText: 'Model *',
          hintText: 'FZ-S, CB300R, Pulsar…',
          optionsBuilder: (_) => modelsForBrand(_brandCtrl.text),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _yearCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Year', hintText: '2023'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _ccCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Engine CC', hintText: '150'),
              ),
            ),
          ],
        ),
      ];

  // ─── Tour builder ───────────────────────────────────────────────────────────

  Widget _buildTour() {
    return PageView.builder(
      controller: _pageCtrl,
      physics: const ClampingScrollPhysics(),
      onPageChanged: (i) => setState(() => _tourSlide = i),
      itemCount: kOnboardingSlides.length,
      itemBuilder: (context, i) {
        final slide = kOnboardingSlides[i];
        return OnboardingSlidePage(
          key: ValueKey(slide.featureKey),
          slide: slide,
          totalSlides: kOnboardingSlides.length,
          slideIndex: i,
          isLastSlide: i == kOnboardingSlides.length - 1,
          onNext: _advanceTour,
          onSkip: _skipTour,
          onShowMe: () => _showMeFor(i),
        );
      },
    );
  }
}

// ─── Step progress bar widget ─────────────────────────────────────────────────

class _SetupProgressBar extends StatelessWidget {
  const _SetupProgressBar({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = ['Your Info', 'Your Bike', 'Feature Tour'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isDone = i < currentStep;
        final isActive = i == currentStep;
        return Expanded(
          child: Row(
            children: [
              // Connector line (not before first)
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isDone || isActive
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              // Dot
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.primary
                      : isActive
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface,
                  border: Border.all(
                    color: isActive || isDone
                        ? AppColors.primary
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
              ),
              // After last dot: trailing line to balance layout
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentStep ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
