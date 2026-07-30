#!/usr/bin/env bash
# Local helper: invoke Flutter from the existing toolchain.
# Source this script or copy the alias line.
export FLUTTER_BAT="/c/Users/sherl/AppData/Local/Temp/next-transfer-toolchain/flutter/bin/flutter.bat"
export DART_BAT="/c/Users/sherl/AppData/Local/Temp/next-transfer-toolchain/flutter/bin/dart.bat"
# Pre-add the toolchain bin dir to PATH so dart-sdk bin tools (if any) resolve.
export PATH="/c/Users/sherl/AppData/Local/Temp/next-transfer-toolchain/flutter/bin:$PATH"

flutter() { "$FLUTTER_BAT" "$@"; }
dart()   { "$DART_BAT" "$@"; }
export -f flutter
export -f dart