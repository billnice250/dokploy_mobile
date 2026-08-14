#!/usr/bin/env bash
set -euo pipefail
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
