#!/usr/bin/env bash
set -euo pipefail
fvm flutter create . --platforms=android,ios
fvm flutter pub get
fvm flutter test
fvm flutter run
