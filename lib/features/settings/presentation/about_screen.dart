import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'about_screen.g.dart';

const sourceCodeUrl = 'https://github.com/malpi-dev/Centavo';

@riverpod
Future<PackageInfo> packageInfo(Ref ref) => PackageInfo.fromPlatform();

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = ref.watch(packageInfoProvider);
    final version = info.when(
      data: (i) => l10n.aboutVersionValue(i.version, i.buildNumber),
      loading: () => '…',
      error: (_, _) => '—',
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Center(
            child: Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              l10n.aboutTagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            key: const Key('about-version'),
            title: Text(l10n.aboutVersion),
            subtitle: Text(version),
          ),
          ListTile(
            key: const Key('about-source'),
            title: Text(l10n.aboutSourceCode),
            subtitle: const Text(sourceCodeUrl),
            trailing: const Icon(Icons.copy),
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: sourceCodeUrl));
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text(l10n.aboutLinkCopied)),
              );
            },
          ),
          ListTile(
            key: const Key('about-licenses'),
            title: Text(l10n.aboutLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
        ],
      ),
    );
  }
}
