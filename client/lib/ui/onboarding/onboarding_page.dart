import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_settings.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.setOnboardingCompleted(true);
  }

  void _next(List<_OnboardingStep> steps) {
    if (_index >= steps.length - 1) {
      _completeOnboarding();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  List<_OnboardingStep> _buildSteps(AppLocalizations l) {
    return [
      _OnboardingStep(
        icon: Icons.auto_awesome_outlined,
        title: l.onboardingWelcomeTitle,
        body: l.onboardingWelcomeBody,
      ),
      _OnboardingStep(
        icon: Icons.flash_on_outlined,
        title: l.onboardingQuickAddTitle,
        body: l.onboardingQuickAddBody,
      ),
      _OnboardingStep(
        icon: Icons.label_outline,
        title: l.onboardingOrganizeTitle,
        body: l.onboardingOrganizeBody,
      ),
      _OnboardingStep(
        icon: Icons.insights_outlined,
        title: l.onboardingInsightsTitle,
        body: l.onboardingInsightsBody,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = _buildSteps(l);
    final isLast = _index == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    l.appTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: steps.length,
                onPageChanged: (value) {
                  setState(() {
                    _index = value;
                  });
                },
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return _OnboardingStepCard(step: step);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  steps.length,
                  (index) => _OnboardingDot(isActive: index == _index),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (isLast)
                    const SizedBox(width: 64)
                  else
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(l.onboardingSkip),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _next(steps),
                    child: Text(isLast ? l.onboardingStart : l.onboardingNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, size: 36, color: accent),
          ),
          const SizedBox(height: 24),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingDot extends StatelessWidget {
  const _OnboardingDot({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
