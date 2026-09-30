import 'package:flutter/material.dart';

/// Messenger of the root `MaterialApp`, so SnackBars (e.g. *Undo*) outlive the
/// screen that raised them.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
