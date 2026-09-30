import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Two confirmations, then wipes the database and the settings. The router
/// redirect then sends the user to Welcome.
Future<void> confirmAndEraseData(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final first = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.eraseTitle),
      content: Text(l10n.eraseMessage),
      actions: [
        TextButton(
          key: const Key('erase-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('erase-continue'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.eraseContinue),
        ),
      ],
    ),
  );
  if (first != true || !context.mounted) return;
  final second = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.eraseFinalTitle),
      content: Text(l10n.eraseFinalMessage),
      actions: [
        TextButton(
          key: const Key('erase-final-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('erase-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.eraseEverything),
        ),
      ],
    ),
  );
  if (second != true) return;
  try {
    await ref.read(localStoreProvider).eraseAll();
    await ref.read(settingsRepositoryProvider).clear();
    ref.invalidate(settingsControllerProvider);
  } on Object catch (e) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(messageFor(e, l10n))),
    );
  }
}
