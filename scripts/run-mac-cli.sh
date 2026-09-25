#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
output_dir="${HOME}/Applications"
bundle_path="${output_dir}/DeskBridgeCLI.app"
output_path="${bundle_path}/Contents/MacOS/DeskBridgeCLI"

mkdir -p "${bundle_path}/Contents/MacOS"
cp "$repo_dir/MacCLI/Info.plist" "${bundle_path}/Contents/Info.plist"
xcrun swiftc \
  -swift-version 5 \
  -o "$output_path" \
  "$repo_dir/MacCLI/main.swift" \
  "$repo_dir/Mac/MacBridge.swift" \
  "$repo_dir/Shared/DeskProtocol.swift"

sign_identity="${DESKBRIDGE_SIGN_IDENTITY:-}"
if [[ -z "$sign_identity" ]]; then
  identity_list="$(security find-identity -v -p codesigning | awk '/Apple Development:/ { print $2 }')"
  identity_count="$(print -r -- "$identity_list" | awk 'NF { count++ } END { print count+0 }')"
  if (( identity_count == 1 )); then
    sign_identity="$identity_list"
  elif (( identity_count > 1 )); then
    print -u2 '複数の Apple Development 証明書があります。DESKBRIDGE_SIGN_IDENTITY を指定してください。'
    exit 1
  else
    sign_identity='-'
    print -u2 '開発用証明書が見つからないためアドホック署名します。再ビルド後は権限を再設定する場合があります。'
  fi
fi
codesign --force --sign "$sign_identity" "$bundle_path"

codesign --verify --strict "$bundle_path"
print "起動: $output_path"
exec "$output_path"
