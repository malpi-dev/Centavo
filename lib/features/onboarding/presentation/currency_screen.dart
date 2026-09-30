import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/features/onboarding/presentation/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  late String _selected = defaultCurrencyForCountry(
    WidgetsBinding.instance.platformDispatcher.locale.countryCode,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    ref.listen(onboardingControllerProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFor(next.error, l10n))),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseCurrency)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l10n.currencyHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? _selected),
              child: ListView(
                children: [
                  for (final c in supportedCurrencies)
                    RadioListTile<String>(
                      key: Key('currency-${c.code}'),
                      value: c.code,
                      title: Text(c.name),
                      subtitle: Text(c.code),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: Semantics(
                  identifier: 'currency-continue',
                  child: FilledButton(
                    key: const Key('currency-continue'),
                    onPressed: state.isLoading
                        ? null
                        : () => ref
                              .read(onboardingControllerProvider.notifier)
                              .completeFreshStart(_selected),
                    child: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.continueLabel),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
