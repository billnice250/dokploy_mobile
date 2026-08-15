#!/bin/sh
set -e

############################
# 1. MOVE TO PROJECT ROOT  #
############################
cd "$CI_PRIMARY_REPOSITORY_PATH/"

echo "Current directory:"
pwd

###################################
# 2. INSTALL FLUTTER FROM GITHUB  #
###################################
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter

##########################################
# 3. MAKE SURE CI USES *THIS* FLUTTER    #
##########################################
export FLUTTER_ROOT="$HOME/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"

echo "Using Flutter from:"
which flutter
flutter --version

########################################
# 4. CREATE REQUIRED PRIVATE ASSET FILE #
########################################
# .env is intentionally gitignored, but pubspec.yaml declares it as a Flutter
# asset. Flutter's release asset bundler requires the file to exist even when
# runtime code treats dotenv loading as optional.
if [ ! -f .env ]; then
  {
    if [ -n "${GOOGLE_SERVER_CLIENT_ID:-}" ]; then
      printf 'GOOGLE_SERVER_CLIENT_ID=%s\n' "$GOOGLE_SERVER_CLIENT_ID"
    else
      printf '# Created by Xcode Cloud for Flutter asset bundling.\n'
    fi
  } > .env
fi

##################################
# 5. GENERATE iOS ENGINE ARTIFACTS
##################################
flutter precache --ios

#############################################
# 6. CLEAN + GET PUB DEPENDENCIES
#############################################
flutter clean
flutter pub get

########################################################
# 7. **CRITICAL STEP**: GENERATE FLUTTER IOS ARTIFACTS #
########################################################
# This is REQUIRED or your build will fail:
# - missing Flutter.xcframework
# - Google Fonts missing
# - missing flutter_assets
# - Xcode archive fails
flutter build ios --release --no-codesign

echo "Flutter iOS build artifacts generated."

#############################################
# 8. DONE — XCODE ARCHIVE WILL NOW WORK
#############################################
ls -R $FLUTTER_ROOT/bin/cache/artifacts/engine/ios
ls -R build/ios/Release-iphoneos/

exit 0
