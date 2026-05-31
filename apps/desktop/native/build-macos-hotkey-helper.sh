#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p build
xcrun swiftc macos-hotkey-listener.swift -o build/workerflow-hotkey
