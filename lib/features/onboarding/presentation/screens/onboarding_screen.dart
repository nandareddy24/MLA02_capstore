import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/fixwise_brand_mark.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../controllers/onboarding_controller.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.highlights,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> highlights;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: LucideIcons.smartphone,
      title: 'Report Your Device Problem',
      description:
          'Select the affected device from your inventory and describe observed symptoms, error codes, and operating conditions in a structured report.',
      highlights: [
        'Quick device selection and asset tracking',
        'Guided symptom chips and severity tagging',
      ],
    ),
    _OnboardingSlide(
      icon: LucideIcons.activity,
      title: 'Understand Possible Faults',
      description:
          'FixWise analyzes your reported symptoms and ranks probable fault categories with transparent confidence indicators and contributing factors.',
      highlights: [
        'Data-backed probable fault ranking',
        'Clear root-cause factors without guesswork',
      ],
    ),
    _OnboardingSlide(
      icon: LucideIcons.shieldAlert,
      title: 'Get Recommended Actions',
      description:
          'Receive severity-aware troubleshooting steps, safety precautions, and clear escalation advice when technician intervention is required.',
      highlights: [
        'Prioritized inspection and repair guidance',
        'Risk-aware escalation and verification logs',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  void _handleNext() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLastPage = _currentIndex == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentContainer(
          maxWidth: 540,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const FixWiseBrandMark(size: 34, showWordmark: true),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Align(
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface(
                                    theme.brightness,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.buttonRadius,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.outline,
                                  ),
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: AppSpacing.iconLg,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                slide.title,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                slide.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Divider(),
                              const SizedBox(height: AppSpacing.md),
                              ...slide.highlights.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        LucideIcons.check,
                                        size: 16,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final active = index == _currentIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: active ? 24 : 8,
                    decoration: BoxDecoration(
                      color: active ? colorScheme.primary : colorScheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (_currentIndex > 0) ...[
                    Expanded(
                      child: SecondaryButton(
                        label: 'Back',
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: isLastPage ? 'Get Started' : 'Next',
                      icon: LucideIcons.arrowRight,
                      onPressed: _handleNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
