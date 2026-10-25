import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/set_sex_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../../helpers/test_l10n.dart';

void main() {
  for (final sex in UserSexEntity.values) {
    testWidgets('profile selector returns ${sex.name}', (tester) async {
      UserSexEntity? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showDialog<UserSexEntity>(
                    context: context,
                    builder: (_) => const SetSexDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.selectSexDialogLabel), findsOneWidget);
      expect(find.byType(SimpleDialogOption), findsNWidgets(2));
      await tester.tap(
        find.text(
          sex == UserSexEntity.male
              ? l10nEn.sexMaleLabel
              : l10nEn.sexFemaleLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(selected, sex);
      expect(find.byType(SetSexDialog), findsNothing);
    });
  }
}
