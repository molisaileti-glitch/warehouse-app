// lib/core/components/app_stepper.dart
//
// A compact horizontal stepper with a clean header, a progress bar,
// a focused content area, and a sticky bottom action rail.

import 'package:flutter/material.dart';

class AppStep {
  final String title;
  final String description;
  final WidgetBuilder contentBuilder;

  /// Return false to block moving to the next step (e.g. form invalid).
  final bool Function()? validate;

  AppStep({
    required this.title,
    required this.description,
    required this.contentBuilder,
    this.validate,
  });
}

class AppStepper extends StatefulWidget {
  final List<AppStep> steps;
  final VoidCallback onComplete;
  final String nextLabel;
  final String completeLabel;
  final String backLabel;
  final bool stickyActions;

  const AppStepper({
    super.key,
    required this.steps,
    required this.onComplete,
    this.nextLabel = 'Next',
    this.completeLabel = 'Create Account',
    this.backLabel = 'Back',
    this.stickyActions = true,
  });

  @override
  State<AppStepper> createState() => AppStepperState();
}

class AppStepperState extends State<AppStepper> {
  int _currentStep = 0;

  void _handleContinue() {
    final step = widget.steps[_currentStep];
    if (step.validate != null && !step.validate!()) return;

    final isLast = _currentStep == widget.steps.length - 1;
    if (isLast) {
      widget.onComplete();
    } else {
      setState(() => _currentStep += 1);
    }
  }

  void _handleCancel() {
    if (_currentStep > 0) setState(() => _currentStep -= 1);
  }

  /// Lets a parent (e.g. after a failed confirm dialog) jump back to a step.
  void goToStep(int index) => setState(() => _currentStep = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        if (widget.stickyActions && hasBoundedHeight) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 18),
                Expanded(child: _buildContentCard(context)),
                const SizedBox(height: 18),
                _buildStickyActionRail(context),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 18),
            _buildContentCard(context),
            const SizedBox(height: 18),
            _buildStickyActionRail(context),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final step = widget.steps[_currentStep];
    final progress = widget.steps.length <= 1
        ? 1.0
        : (_currentStep + 1) / widget.steps.length;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${_currentStep + 1} of ${widget.steps.length}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 28,
              height: 1.08,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE7ECE8),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(_currentStep),
        width: double.infinity,
        padding: const EdgeInsets.only(top: 18),
        child: SingleChildScrollView(
          child: widget.steps[_currentStep].contentBuilder(context),
        ),
      ),
    );
  }

  Widget _buildStickyActionRail(BuildContext context) {
    final theme = Theme.of(context);
    final hasBack = _currentStep > 0;
    final isLast = _currentStep == widget.steps.length - 1;

    Widget actionButton({
      required String label,
      required VoidCallback onPressed,
      required bool primary,
      required bool destructive,
    }) {
      final style = primary
          ? FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              backgroundColor: destructive ? theme.colorScheme.error : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            )
          : OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: destructive ? theme.colorScheme.error : theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            );

      return primary
          ? FilledButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            );
    }

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (!hasBack)
              SizedBox(
                width: double.infinity,
                child: actionButton(
                  label: isLast ? widget.completeLabel : widget.nextLabel,
                  onPressed: _handleContinue,
                  primary: true,
                  destructive: false,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: actionButton(
                      label: widget.backLabel,
                      onPressed: _handleCancel,
                      primary: false,
                      destructive: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: actionButton(
                      label: isLast ? widget.completeLabel : widget.nextLabel,
                      onPressed: _handleContinue,
                      primary: true,
                      destructive: false,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
