import 'dart:async';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/search/catalogue_preferences.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DatabasesScreen extends StatefulWidget {
  const DatabasesScreen({super.key, this.preferences});
  final CataloguePreferences? preferences;

  @override
  State<DatabasesScreen> createState() => _DatabasesScreenState();
}

class _DatabasesScreenState extends State<DatabasesScreen> {
  late final preferences =
      widget.preferences ?? locator<CataloguePreferences>();
  late Future<void> _loading;
  late final StreamSubscription<void> _subscription;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loading = preferences.load();
    _subscription = preferences.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggle(String id, bool enabled) async {
    setState(() => _saving = true);
    try {
      await preferences.setEnabled(id, enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).displayPreferenceSaveErrorLabel),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsDatabasesLabel)),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorDialog(
              errorText: s.catalogueLoadFailedLabel,
              onRefreshPressed: () => setState(() {
                _loading = preferences.load();
              }),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Semantics(
            identifier: 'database-list',
            child: ListView(
              children: [
                for (final source in preferences.sources)
                  Semantics(
                    identifier: 'database-${source.id}-enabled',
                    child: SwitchListTile(
                      title: Text(
                        source.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        s.catalogueReleasesLabel(source.releaseSummary),
                      ),
                      value: preferences.isEnabled(source.id),
                      onChanged: _saving
                          ? null
                          : (enabled) => _toggle(source.id, enabled),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
