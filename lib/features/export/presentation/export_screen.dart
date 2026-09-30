import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/month_selector.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:centavo/features/export/presentation/export_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _RangeOption { current, month, all }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _RangeOption _option = _RangeOption.current;
  YearMonth? _chosen;

  ExportRange _range(YearMonth current) => switch (_option) {
    _RangeOption.current => ExportMonth(current),
    _RangeOption.month => ExportMonth(_chosen ?? current),
    _RangeOption.all => const ExportAll(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current = YearMonth.fromLocalDate(ref.watch(clockProvider).today());
    final state = ref.watch(exportControllerProvider);
    final emptyRange =
        state.error is ExportError &&
        (state.error! as ExportError).reason == ExportErrorReason.emptyRange;
    ref.listen(exportControllerProvider, (_, next) {
      final error = next.error;
      if (next is AsyncError &&
          !(error is ExportError &&
              error.reason == ExportErrorReason.emptyRange)) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(messageFor(error!, l10n))),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RadioGroup<_RangeOption>(
            groupValue: _option,
            onChanged: (v) {
              ref.invalidate(exportControllerProvider);
              setState(() => _option = v ?? _option);
            },
            child: Column(
              children: [
                RadioListTile<_RangeOption>(
                  key: const Key('export-range-current'),
                  value: _RangeOption.current,
                  title: Text(l10n.exportThisMonth),
                ),
                RadioListTile<_RangeOption>(
                  key: const Key('export-range-month'),
                  value: _RangeOption.month,
                  title: Text(l10n.exportChooseMonth),
                ),
                if (_option == _RangeOption.month)
                  MonthSelector(
                    month: _chosen ?? current,
                    maxMonth: current,
                    onChanged: (m) {
                      ref.invalidate(exportControllerProvider);
                      setState(() => _chosen = m);
                    },
                  ),
                RadioListTile<_RangeOption>(
                  key: const Key('export-range-all'),
                  value: _RangeOption.all,
                  title: Text(l10n.exportAllTime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'export-run',
            child: FilledButton(
              key: const Key('export-run'),
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(exportControllerProvider.notifier)
                        .export(_range(current)),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.exportRun),
            ),
          ),
          if (emptyRange) ...[
            const SizedBox(height: 12),
            Text(
              l10n.errorExportEmptyRange,
              key: const Key('export-empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.exportColumnsInfo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
