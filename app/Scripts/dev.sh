#!/bin/zsh
# Build (debug) and launch Container.app
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
./Scripts/build.sh
open build/Container.app
