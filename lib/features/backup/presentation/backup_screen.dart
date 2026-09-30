import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/backup/domain/run_backup.dart';
import 'package:centavo/features/backup/presentation/backup_controller.dart';
import 'package:centavo/features/backup/presentation/backup_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: AsyncStateView<String?>(
        value: ref.watch(signedInEmailProvider),
        onRetry: () => ref.invalidate(signedInEmailProvider),
        data: (email) =>
            email == null ? const _SignedOut() : _SignedIn(email: email),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.backupNotSignedIn, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final benefit in [
              l10n.backupBenefit1,
              l10n.backupBenefit2,
              l10n.backupBenefit3,
            ])
              ListTile(
                dense: true,
                leading: Icon(Icons.check, color: theme.colorScheme.primary),
                title: Text(benefit),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('backup-sign-in'),
              onPressed: () => context.push(Routes.backupSignIn),
              child: Text(l10n.backupSignInAction),
            ),
          ],
        ),
      ),
    );
  }
}

String _stepLabel(BackupStep step, AppLocalizations l10n) => switch (step) {
  BackupStep.preparing => l10n.backupStepPreparing,
  BackupStep.uploadingCategories => l10n.backupStepCategories,
  BackupStep.uploadingBudgets => l10n.backupStepBudgets,
  BackupStep.uploadingTransactions => l10n.backupStepTransactions,
};

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final op = ref.watch(backupControllerProvider);
    final busy = op.isLoading;
    final step = ref.watch(backupStepProvider);
    final lastBackup = ref.watch(lastBackupAtProvider);
    final settings = ref.watch(settingsControllerProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(l10n.backupSignedInAs(email)),
          subtitle: Text(
            key: const Key('backup-last'),
            _lastBackupText(lastBackup.value, ref, l10n),
          ),
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LinearProgressIndicator(key: Key('backup-progress')),
                if (step != null) ...[
                  const SizedBox(height: 8),
                  Text(_stepLabel(step, l10n)),
                ],
              ],
            ),
          ),
        if (op.hasError)
          _ErrorBanner(
            message: messageFor(op.error!, l10n),
            onRetry: () => ref.read(backupControllerProvider.notifier).retry(),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('backup-now'),
            onPressed: busy ? null : () => _backUp(ref, l10n),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(l10n.backupNow),
          ),
        ),
        SwitchListTile(
          key: const Key('backup-auto'),
          title: Text(l10n.backupAutomatic),
          subtitle: Text(l10n.backupAutomaticSubtitle),
          value: settings.autoBackupEnabled,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .change((s) => s.copyWith(autoBackupEnabled: value)),
        ),
        const Divider(),
        ListTile(
          key: const Key('backup-restore'),
          leading: const Icon(Icons.cloud_download_outlined),
          title: Text(l10n.backupRestore),
          enabled: !busy,
          onTap: () => _restore(context, ref),
        ),
        ListTile(
          key: const Key('backup-delete'),
          leading: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.error,
          ),
          title: Text(
            l10n.backupDelete,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          enabled: !busy,
          onTap: () => _delete(context, ref),
        ),
        ListTile(
          key: const Key('backup-sign-out'),
          leading: const Icon(Icons.logout),
          title: Text(l10n.backupSignOut),
          enabled: !busy,
          onTap: () => _signOut(context, ref),
        ),
      ],
    );
  }

  String _lastBackupText(DateTime? last, WidgetRef ref, AppLocalizations l10n) {
    if (last == null) return l10n.backupLastBackupNever;
    final now = ref.read(clockProvider).nowUtc();
    final when = now.difference(last).abs() < const Duration(minutes: 1)
        ? l10n.backupJustNow
        : DateFormat.yMMMd(l10n.localeName).add_Hm().format(last.toLocal());
    return l10n.backupLastBackup(when);
  }

  Future<void> _backUp(WidgetRef ref, AppLocalizations l10n) async {
    final ok = await ref.read(backupControllerProvider.notifier).backUpNow();
    if (ok) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l10n.backupDone)),
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    required String prefix,
    bool destructive = false,
  }) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            key: Key('$prefix-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: Key('$prefix-confirm'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.backupRestoreConfirmTitle,
      message: l10n.backupRestoreConfirmMessage,
      action: l10n.backupRestoreConfirm,
      prefix: 'restore',
    );
    if (!confirmed) return;
    final controller = ref.read(backupControllerProvider.notifier);
    if (await controller.restore(fromWelcome: false)) {
      final r = controller.lastRestore;
      if (r != null) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              l10n.backupRestored(
                r.transactions.toString(),
                r.categories.toString(),
                r.budgets.toString(),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final first = await _confirm(
      context,
      title: l10n.backupDeleteConfirmTitle,
      message: l10n.backupDeleteConfirmMessage,
      action: l10n.eraseContinue,
      prefix: 'backup-delete-first',
    );
    if (!first || !context.mounted) return;
    final second = await _confirm(
      context,
      title: l10n.backupDeleteFinalTitle,
      message: l10n.backupDeleteFinalMessage,
      action: l10n.backupDeleteConfirm,
      prefix: 'backup-delete-final',
      destructive: true,
    );
    if (!second) return;
    if (await ref.read(backupControllerProvider.notifier).deleteBackup()) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l10n.backupDeleted)),
      );
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.backupSignOutConfirmTitle,
      message: l10n.backupSignOutConfirmMessage,
      action: l10n.backupSignOut,
      prefix: 'sign-out',
    );
    if (!confirmed) return;
    await ref.read(backupControllerProvider.notifier).signOut();
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('backup-error'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            key: const Key('backup-retry'),
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }
}
