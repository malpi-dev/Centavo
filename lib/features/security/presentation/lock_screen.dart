import 'dart:async';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/features/security/presentation/lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prompt once on arrival.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_unlock());
    });
  }

  Future<void> _unlock() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(lockControllerProvider.notifier).unlock(l10n.lockReason);
    } on DomainError catch (e) {
      if (mounted) setState(() => _error = errorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? scheme.surface : scheme.primary;
    final foreground = dark ? scheme.onSurface : scheme.onPrimary;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/splash_logo.png',
                    height: 72,
                    width: 72,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.lockTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    identifier: 'lock-unlock',
                    child: FilledButton(
                      key: const Key('lock-unlock'),
                      style: dark
                          ? null
                          : FilledButton.styleFrom(
                              backgroundColor: scheme.onPrimary,
                              foregroundColor: scheme.primary,
                            ),
                      onPressed: _busy ? null : _unlock,
                      child: Text(l10n.lockUnlock),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        key: const Key('lock-waiting'),
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const Key('lock-error'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
