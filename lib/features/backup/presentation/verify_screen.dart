import 'dart:async';

import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/backup/presentation/backup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({
    required this.email,
    this.fromWelcome = false,
    super.key,
  });

  final String email;
  final bool fromWelcome;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const _resendSeconds = 60;

  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _busy = false;
  bool _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
      }
      if (mounted) setState(() => _secondsLeft = _secondsLeft - 1);
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authRepositoryProvider).sendCode(widget.email);
      if (!mounted) return;
      _startCountdown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.verifyCodeSent)));
    } on Object catch (e) {
      if (mounted) setState(() => _error = messageFor(e, context.l10n));
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyCode(email: widget.email, code: _code.text.trim());
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = messageFor(e, context.l10n);
        });
      }
      return;
    }
    if (!mounted) return;
    if (widget.fromWelcome) {
      await _restore();
    } else {
      // First full backup; failures are shown on the Backup screen.
      await ref.read(backupControllerProvider.notifier).backUpNow();
      if (mounted) context.go(Routes.backup);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _restoring = true;
      _error = null;
    });
    final controller = ref.read(backupControllerProvider.notifier);
    final ok = await controller.restore(fromWelcome: true);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.dashboard);
      return;
    }
    final error = ref.read(backupControllerProvider).error;
    setState(() {
      _busy = false;
      _restoring = false;
    });
    if (error is NotFoundError) {
      await _showNoBackup();
    } else {
      setState(() => _error = messageFor(error!, context.l10n));
    }
  }

  Future<void> _showNoBackup() async {
    final l10n = context.l10n;
    final startFresh = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noBackupFoundTitle),
        content: Text(l10n.noBackupFoundMessage),
        actions: [
          TextButton(
            key: const Key('no-backup-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('no-backup-start-fresh'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.startFresh),
          ),
        ],
      ),
    );
    if ((startFresh ?? false) && mounted) context.go(Routes.welcomeCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_restoring) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(key: Key('restoring')),
                const SizedBox(height: 16),
                Text(l10n.restoringTitle),
              ],
            ),
          ),
        ),
      );
    }
    final isDemo = ref.watch(appModeControllerProvider) == AppMode.demo;
    final retryRestore = widget.fromWelcome && _error != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.verifyMessage(widget.email)),
          const SizedBox(height: 24),
          TextField(
            key: const Key('backup-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.verifyCodeLabel,
              helperText: isDemo ? l10n.verifyDemoHint : null,
              errorText: _error,
            ),
            onSubmitted: (_) => _busy ? null : _verify(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('backup-verify'),
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.verifyAction),
          ),
          if (retryRestore) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('restore-retry'),
              onPressed: _busy ? null : _restore,
              child: Text(l10n.retry),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            key: const Key('backup-resend'),
            onPressed: _secondsLeft > 0 || _busy ? null : _resend,
            child: Text(
              _secondsLeft > 0
                  ? l10n.verifyResendIn(_secondsLeft.toString())
                  : l10n.verifyResend,
            ),
          ),
        ],
      ),
    );
  }
}
