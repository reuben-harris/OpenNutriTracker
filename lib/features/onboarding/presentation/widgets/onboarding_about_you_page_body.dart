import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/utils/bounds/validator.dart';
import 'package:opennutritracker/features/onboarding/domain/entity/user_sex_selection_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class OnboardingAboutYouPageBody extends StatefulWidget {
  final Function(bool active, UserSexSelectionEntity? sex, DateTime? birthday)
  setPageContent;

  final UserSexSelectionEntity? initialSex;
  final DateTime? initialBirthday;

  const OnboardingAboutYouPageBody({
    super.key,
    required this.setPageContent,
    this.initialSex,
    this.initialBirthday,
  });

  @override
  State<OnboardingAboutYouPageBody> createState() =>
      _OnboardingAboutYouPageBodyState();
}

class _OnboardingAboutYouPageBodyState
    extends State<OnboardingAboutYouPageBody> {
  final _dateInput = TextEditingController();
  DateTime? _selectedDate;

  UserSexSelectionEntity? _selectedSex;

  @override
  void initState() {
    super.initState();
    _selectedSex = widget.initialSex;
    _selectedDate = widget.initialBirthday;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedDate != null && _dateInput.text.isEmpty) {
      _dateInput.text = MaterialLocalizations.of(
        context,
      ).formatCompactDate(_selectedDate!);
    }
  }

  UserSexEntity _toEntity(UserSexSelectionEntity selection) {
    switch (selection) {
      case UserSexSelectionEntity.sexMale:
        return UserSexEntity.male;
      case UserSexSelectionEntity.sexFemale:
        return UserSexEntity.female;
    }
  }

  void _onSexSelected(UserSexSelectionEntity selection) {
    setState(() {
      _selectedSex = selection;
      checkCorrectInput();
    });
  }

  @override
  Widget build(BuildContext context) {
    final birthday = _selectedDate;
    final showAdultEquationNotice =
        birthday != null && ValueValidator.isUnderAdultAge(birthday);
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  S.of(context).sexLabel,
                  maxLines: 1,
                  minFontSize: 16,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: S.of(context).sourcesIconTooltip,
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SourcesScreen()),
                ),
              ),
            ],
          ),
          Text(
            S.of(context).onboardingSexQuestionSubtitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _buildSexChip(UserSexSelectionEntity.sexMale),
              _buildSexChip(UserSexSelectionEntity.sexFemale),
            ],
          ),
          const SizedBox(height: 32.0),
          Text(
            S.of(context).ageLabel,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            S.of(context).onboardingBirthdayQuestionSubtitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16.0),
          Semantics(
            identifier: 'onboarding-birthday-field',
            child: TextFormField(
              controller: _dateInput,
              readOnly: true,
              decoration: InputDecoration(
                hintText: S.of(context).onboardingEnterBirthdayLabel,
                labelText: S.of(context).onboardingEnterBirthdayLabel,
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onTap: onDateInputClicked,
            ),
          ),
          if (showAdultEquationNotice) ...[
            const SizedBox(height: 12.0),
            _buildAdultEquationNotice(),
          ],
        ],
      ),
    );
  }

  /// Shown for 13–18 year olds. The calorie goal is still calculated, but
  /// the IOM 2005 equations behind it are the adult set, and saying so is
  /// more honest than quietly handing a teenager an adult number.
  Widget _buildAdultEquationNotice() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.of(context).onboardingAdultEquationNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSexChip(UserSexSelectionEntity selection) {
    final entity = _toEntity(selection);
    return Semantics(
      identifier: 'onboarding-sex-${entity.name}',
      child: ChoiceChip(
        label: Text(entity.getName(context)),
        avatar: entity.getIcon(size: 18),
        selected: _selectedSex == selection,
        onSelected: (_) => _onSexSelected(selection),
      ),
    );
  }

  void onDateInputClicked() async {
    final selected = _selectedDate;
    final pickedDate = await showDatePicker(
      context: context,
      // Nobody scrolls month by month to 1994, so the picker opens on the
      // year grid.
      initialDatePickerMode: DatePickerMode.year,
      initialDate: selected != null
          ? ValueValidator.clampBirthday(selected)
          : ValueValidator.getInitialBirthdayDate(),
      firstDate: ValueValidator.getFirstDate(),
      lastDate: ValueValidator.getLastDate(),
    );
    if (pickedDate == null || !mounted) return;
    final localizations = MaterialLocalizations.of(context);
    final formattedDate = localizations.formatCompactDate(pickedDate);
    setState(() {
      _selectedDate = pickedDate;
      _dateInput.text = formattedDate;
      checkCorrectInput();
    });
  }

  void checkCorrectInput() {
    if (_selectedSex != null && _selectedDate != null) {
      widget.setPageContent(true, _selectedSex, _selectedDate);
    } else {
      widget.setPageContent(false, null, null);
    }
  }
}
