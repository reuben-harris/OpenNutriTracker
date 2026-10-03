import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Returns the entered amount after the caller's save succeeds. Persistence
/// belongs to the day controller; failures leave the correction on screen.
class LogWaterDialog extends StatefulWidget {
  static const int sliderMaxMl = 1000;
  static const int sliderStepMl = 50;
  static const int sliderDivisions = sliderMaxMl ~/ sliderStepMl;
  static const int sliderDefaultMl = 250;

  final int? initialAmount;
  final Future<void> Function(int amount) onSave;

  const LogWaterDialog({super.key, this.initialAmount, required this.onSave});

  @override
  State<LogWaterDialog> createState() => _LogWaterDialogState();
}

class _LogWaterDialogState extends State<LogWaterDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.initialAmount ?? LogWaterDialog.sliderDefaultMl}',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.initialAmount == null
              ? s.logWaterDialogTitle
              : s.editWaterAmountLabel,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: MediaQuery.textScalerOf(context).scale(14) > 20
                ? 14
                : null,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                identifier: 'log-water-amount',
                child: TextField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.trendsWaterLabel,
                    suffixText: s.mlLabel,
                    errorText: _error,
                    errorMaxLines: 3,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'log-water-slider',
                child: Slider(
                  value: (int.tryParse(_amount.text) ?? 0)
                      .clamp(0, LogWaterDialog.sliderMaxMl)
                      .toDouble(),
                  min: 0,
                  max: LogWaterDialog.sliderMaxMl.toDouble(),
                  divisions: LogWaterDialog.sliderDivisions,
                  label: '${_amount.text} ${s.mlLabel}',
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _amount.text = '${value.round()}';
                          _error = null;
                        }),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(s.dialogCancelLabel),
          ),
          Semantics(
            identifier: 'log-water-save',
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.buttonSaveLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _amount.text.trim();
    final amount = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) || amount == null || amount <= 0) {
      setState(() => _error = S.of(context).waterAmountValidationLabel);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(amount);
      if (mounted) Navigator.pop(context, amount);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.of(context).waterSaveErrorLabel;
        });
      }
    }
  }
}
