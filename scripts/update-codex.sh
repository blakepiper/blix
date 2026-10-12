# Run from the Blix checkout. Resolve once so both architectures use one release.
test -f flake.nix && test -f flake.lock && test -f overlays/codex.nix || {
  echo 'Run this command from the Blix repository root.' >&2
  exit 1
}
release=$(curl --fail --silent --show-error --retry 3 \
  https://api.github.com/repos/openai/codex/releases/latest)
tag=$(jq -er '
  select(.draft == false and .prerelease == false)
  | .tag_name | select(test("^rust-v[0-9]+\\.[0-9]+\\.[0-9]+$"))
' <<< "$release")

# Refuse incomplete releases before changing any files.
for arch in x86_64 aarch64; do
  url="https://github.com/openai/codex/releases/download/$tag/codex-package-$arch-unknown-linux-musl.tar.gz"
  jq -e --arg url "$url" 'any(.assets[]; .browser_download_url == $url)' \
    <<< "$release" >/dev/null
done

# Restore both files if fetching or locking either platform fails.
backup=$(mktemp -d)
cp flake.nix flake.lock "$backup/"
cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    cp "$backup/flake.nix" flake.nix
    cp "$backup/flake.lock" flake.lock
  fi
  rm -rf "$backup"
}
trap cleanup EXIT

sed -i -E \
  "s|https://github.com/openai/codex/releases/download/rust-v[0-9]+\.[0-9]+\.[0-9]+/codex-package-|https://github.com/openai/codex/releases/download/$tag/codex-package-|g" \
  flake.nix
nix flake update codex-x86_64 codex-aarch64
echo "Pinned Codex $tag for x86_64-linux and aarch64-linux. Review the diff and rebuild to install."
