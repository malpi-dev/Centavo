import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:flutter/material.dart';

/// Placeholder until its phase replaces it.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabTransactions)),
      body: EmptyState(icon: Icons.receipt_long, title: l10n.comingSoon),
    );
  }
}
