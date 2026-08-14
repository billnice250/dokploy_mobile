#!/usr/bin/env bash
set -euo pipefail
flutter format --set-exit-if-changed lib test
flutter analyze
flutter test
