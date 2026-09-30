import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/security/presentation/lock_controller.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/presentation/erase_data.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/settings/presentation/settings_providers.dart';
import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _themeLabel(AppThemePreference p, AppLocalizations l10n) => switch (p) {
  AppThemePreference.system => l10n.themeSystem,
  AppThemePreference.light => l10n.themeLight,
  AppThemePreference.dark => l10n.themeDark,
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final isDemo = ref.watch(appModeControllerProvider) == AppMode.demo;
    final deviceSecure = ref.watch(deviceSecureProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        children: [
          _Section(l10n.settingsSectionAppearance),
          ListTile(
            key: const Key('settings-theme'),
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsTheme),
            subtitle: Text(_themeLabel(settings.themePreference, l10n)),
            onTap: () => _pickTheme(context, ref, settings.themePreference),
          ),
          ListTile(
            key: const Key('settings-currency'),
            leading: const Icon(Icons.payments_outlined),
            title: Text(l10n.settingsCurrency),
            subtitle: Text(
              '${currencyByCode(settings.currencyCode).name} '
              '(${settings.currencyCode})',
            ),
            onTap: () => _pickCurrency(context, ref, settings.currencyCode),
          ),
          _Section(l10n.settingsSectionSecurity),
          _AppLockTile(
            enabled: settings.biometricLockEnabled,
            deviceSecure: deviceSecure,
          ),
          _Section(l10n.settingsSectionData),
          ListTile(
            key: const Key('settings-categories'),
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.categoriesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.categories),
          ),
          ListTile(
            key: const Key('settings-export'),
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.settingsExport),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.export),
          ),
          if (!isDemo)
            ListTile(
              key: const Key('settings-erase'),
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.settingsErase,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => confirmAndEraseData(context, ref),
            ),
          if (isDemo) ...[
            _Section(l10n.settingsSectionDemo),
            ListTile(
              key: const Key('settings-exit-demo'),
              leading: const Icon(Icons.logout),
              title: Text(l10n.exitDemo),
              onTap: () =>
                  ref.read(appModeControllerProvider.notifier).exitDemo(),
            ),
          ],
          _Section(l10n.settingsSectionAbout),
          ListTile(
            key: const Key('settings-about'),
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.about),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemePreference current,
  ) async {
    final l10n = context.l10n;
    final picked = await showDialog<AppThemePreference>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.settingsTheme),
        children: [
          RadioGroup<AppThemePreference>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              children: [
                for (final p in AppThemePreference.values)
                  RadioListTile<AppThemePreference>(
                    key: Key('theme-${p.name}'),
                    value: p,
                    title: Text(_themeLabel(p, l10n)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .change((s) => s.copyWith(themePreference: picked));
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.settingsCurrency),
        children: [
          SizedBox(
            width: double.maxFinite,
            child: RadioGroup<String>(
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v),
              child: Column(
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
        ],
      ),
    );
    if (picked == null || picked == current || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.currencyChangeTitle),
        content: Text(l10n.currencyChangeWarning),
        actions: [
          TextButton(
            key: const Key('currency-change-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('currency-change-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.currencyChangeConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .change((s) => s.copyWith(currencyCode: picked));
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AppLockTile extends ConsumerWidget {
  const _AppLockTile({required this.enabled, required this.deviceSecure});

  final bool enabled;
  final AsyncValue<bool> deviceSecure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final secure = deviceSecure.value;
    // Loading / error: keep the switch disabled without claiming the device is
    // insecure.
    final canToggle = secure ?? false;
    final subtitle = switch (deviceSecure) {
      AsyncData(:final value) when !value => l10n.appLockNeedsScreenLock,
      _ => l10n.appLockSubtitle,
    };
    return SwitchListTile(
      key: const Key('settings-app-lock'),
      secondary: const Icon(Icons.lock_outline),
      title: Text(l10n.settingsAppLock),
      subtitle: Text(subtitle),
      value: enabled,
      onChanged: canToggle || enabled
          ? (value) => _toggle(context, ref, value)
          : null,
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final l10n = context.l10n;
    final controller = ref.read(settingsControllerProvider.notifier);
    if (!value) {
      await controller.change((s) => s.copyWith(biometricLockEnabled: false));
      return;
    }
    try {
      await ref
          .read(lockControllerProvider.notifier)
          .confirmIdentity(l10n.appLockConfirmReason);
      await controller.change((s) => s.copyWith(biometricLockEnabled: true));
    } on Object catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(messageFor(e, l10n))),
      );
    }
  }
}
