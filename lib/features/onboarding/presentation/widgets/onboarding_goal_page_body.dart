import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_goal_selection_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class OnboardingGoalPageBody extends StatefulWidget {
  final Function(bool active, UserGoalSelectionEntity? selectedGoal)
  setButtonContent;
  final UserGoalSelectionEntity? initialGoal;

  const OnboardingGoalPageBody({
    super.key,
    required this.setButtonContent,
    this.initialGoal,
  });

  @override
  State<OnboardingGoalPageBody> createState() => _OnboardingGoalPageBodyState();
}

class _OnboardingGoalPageBodyState extends State<OnboardingGoalPageBody> {
  late UserGoalSelectionEntity? _selected = widget.initialGoal;

  String _label(UserGoalSelectionEntity goal) {
    switch (goal) {
      case UserGoalSelectionEntity.loseWeight:
        return S.of(context).goalLoseWeight;
      case UserGoalSelectionEntity.maintainWeight:
        return S.of(context).goalMaintainWeight;
      case UserGoalSelectionEntity.gainWeigh:
        return S.of(context).goalGainWeight;
    }
  }

  static const _identifierSuffix = {
    UserGoalSelectionEntity.loseWeight: 'lose',
    UserGoalSelectionEntity.maintainWeight: 'maintain',
    UserGoalSelectionEntity.gainWeigh: 'gain',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context).goalLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              S.of(context).onboardingGoalQuestionSubtitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Dimens.spacing16),
            for (final goal in UserGoalSelectionEntity.values) ...[
              _buildGoalRow(goal),
              const SizedBox(height: Dimens.spacing8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(UserGoalSelectionEntity goal) {
    return Semantics(
      identifier: 'onboarding-goal-${_identifierSuffix[goal]}',
      child: ChoiceChip(
        label: Text(
          _label(goal),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        selected: _selected == goal,
        onSelected: (_) => _onSelected(goal),
      ),
    );
  }

  void _onSelected(UserGoalSelectionEntity goal) {
    setState(() => _selected = goal);
    widget.setButtonContent(true, goal);
  }
}
