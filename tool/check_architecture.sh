#!/usr/bin/env bash
# Fails when a layer imports something it must not (docs/implementation/00-guia-general.md §4.1).
set -uo pipefail
cd "$(dirname "$0")/.."
status=0

domain_dirs=$(find lib -type d -name domain)
domain_forbidden="^import '(package:flutter/|package:flutter_riverpod|package:riverpod|package:drift|package:supabase|package:supabase_flutter|package:shared_preferences|package:local_auth|package:share_plus|package:path_provider|package:intl|package:uuid|dart:io|dart:ui)|^import '.*(/|^)(data|presentation)/"
if [ -n "$domain_dirs" ] && grep -rEn --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' "$domain_forbidden" $domain_dirs; then
  echo "ERROR: domain/ must not import frameworks, backend libraries, data/ or presentation/."
  status=1
fi

presentation_dirs=$(find lib -type d -name presentation)
presentation_forbidden="^import '(package:drift|package:supabase|package:supabase_flutter|package:centavo/core/database/|package:centavo/features/[a-z_]+/data/)|^import '(\.\./)+data/"
if [ -n "$presentation_dirs" ] && grep -rEn --include='*.dart' --exclude='*.g.dart' "$presentation_forbidden" $presentation_dirs; then
  echo "ERROR: presentation/ must not import Drift, Supabase or data/ (use lib/core/di/repository_providers.dart)."
  status=1
fi

[ $status -eq 0 ] && echo "Architecture check passed."
exit $status
