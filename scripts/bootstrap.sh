#!/usr/bin/env bash
set -euo pipefail
flutter create . --platforms=android,ios
flutter pub get
flutter test
flutter run
