import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for confirmation, soft-deletes and shows a 4 s SnackBar with Undo.
/// Returns true if deleted.
Future<bool> confirmAndDeleteTransaction(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteTransactionTitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('tx-delete-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  final repository = ref.read(transactionRepositoryProvider);
  final messenger = rootScaffoldMessengerKey.currentState;
  try {
    await repository.softDelete(id);
  } on Object catch (error) {
    messenger?.showSnackBar(SnackBar(content: Text(messageFor(error, l10n))));
    return false;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.transactionDeleted),
        // A SnackBar with an action persists by default; auto-dismiss after
        // the default 4 s instead.
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            try {
              await repository.restore(id);
            } on Object catch (error) {
              messenger.showSnackBar(
                SnackBar(content: Text(messageFor(error, l10n))),
              );
            }
          },
        ),
      ),
    );
  return true;
}
