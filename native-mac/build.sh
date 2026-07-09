#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="QuickBoard"
APP_DIR="${APP_NAME}.app"
BIN="${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "==> 编译 Swift 原生外壳"
swiftc -O \
  -framework Cocoa -framework WebKit \
  -Xfrontend -strict-concurrency=minimal \
  main.swift -o "${APP_NAME}"

echo "==> 组装 .app 包"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
mv "${APP_NAME}" "${BIN}"
cp Info.plist              "${APP_DIR}/Contents/Info.plist"
cp index.html three.min.js icon.icns "${APP_DIR}/Contents/Resources/"

echo "==> 完成：${APP_DIR}"
du -sh "${APP_DIR}"
