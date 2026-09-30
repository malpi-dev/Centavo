import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({this.fromWelcome = false, super.key});

  final bool fromWelcome;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendCode(email);
      if (!mounted) return;
      final from = widget.fromWelcome ? 'welcome' : 'settings';
      await context.push(
        '${Routes.backupVerify}?email=${Uri.encodeQueryComponent(email)}'
        '&from=$from',
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = messageFor(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDemo = ref.watch(appModeControllerProvider) == AppMode.demo;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.signInSubtitle),
          const SizedBox(height: 24),
          TextField(
            key: const Key('backup-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _send(),
            decoration: InputDecoration(
              labelText: l10n.signInEmailLabel,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('backup-send-code'),
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.signInSendCode),
          ),
          if (!isDemo) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('sign-in-explore-demo'),
              onPressed: () =>
                  ref.read(appModeControllerProvider.notifier).enterDemo(),
              child: Text(l10n.exploreDemo),
            ),
          ],
        ],
      ),
    );
  }
}
