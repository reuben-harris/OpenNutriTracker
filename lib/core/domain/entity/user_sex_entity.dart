import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/dbo/user_sex_dbo.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum UserSexEntity {
  male,
  female;

  static const Color maleColor = Color(0xFF5BCEFA);
  static const Color femaleColor = Color(0xFFF5A9B8);

  factory UserSexEntity.fromUserSexDBO(UserSexDBO sexDBO) {
    switch (sexDBO) {
      case UserSexDBO.male:
        return UserSexEntity.male;
      case UserSexDBO.female:
        return UserSexEntity.female;
    }
  }

  String getName(BuildContext context) {
    switch (this) {
      case UserSexEntity.male:
        return S.of(context).sexMaleLabel;
      case UserSexEntity.female:
        return S.of(context).sexFemaleLabel;
    }
  }

  Color getColor() {
    switch (this) {
      case UserSexEntity.male:
        return maleColor;
      case UserSexEntity.female:
        return femaleColor;
    }
  }

  Widget getIcon({double size = 24, Color? color}) {
    switch (this) {
      case UserSexEntity.male:
        return Icon(Icons.male_outlined, size: size, color: color ?? maleColor);
      case UserSexEntity.female:
        return Icon(
          Icons.female_outlined,
          size: size,
          color: color ?? femaleColor,
        );
    }
  }
}
