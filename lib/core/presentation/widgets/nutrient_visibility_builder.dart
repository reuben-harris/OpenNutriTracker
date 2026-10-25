import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';

/// One subscription owns visibility updates for each nutrient surface.
class NutrientVisibilityBuilder extends StatefulWidget {
  final Widget Function(BuildContext, Map<String, bool>, Map<String, bool>)
  builder;
  const NutrientVisibilityBuilder({super.key, required this.builder});
  @override
  State<NutrientVisibilityBuilder> createState() =>
      _NutrientVisibilityBuilderState();
}

class _NutrientVisibilityBuilderState extends State<NutrientVisibilityBuilder> {
  ConfigEntity? _lastConfig;
  late Stream<ConfigEntity>? _config = _watch();
  Stream<ConfigEntity>? _watch() => locator.isRegistered<GetConfigUsecase>()
      ? locator<GetConfigUsecase>().watchConfig()
      : null;
  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return widget.builder(context, const {}, const {});
    }
    return StreamBuilder<ConfigEntity>(
      stream: _config,
      builder: (context, snapshot) {
        final config = snapshot.data ?? _lastConfig;
        if (snapshot.data != null) {
          _lastConfig = snapshot.data;
        }
        if (config == null) {
          if (snapshot.hasError) {
            return Center(
              child: Semantics(
                identifier: 'nutrient-settings-retry',
                child: TextButton.icon(
                  onPressed: () => setState(() => _config = _watch()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(S.of(context).retryLabel),
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder(
          context,
          config.nutrientPanelVisibility,
          config.nutrientInfoVisibility,
        );
      },
    );
  }
}
