#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"
state=$(realpath -m "${CAPY_FLATPAK_BUILD_DIR:-target/flatpak}")
export FLATPAK_USER_DIR=${FLATPAK_USER_DIR:-$state/installation}
test -f "$state/.capy-flatpak-build"
test -f "$state/app/metadata"
output="$root/dist/appimage"
if [[ -e "$output" && ! -f "$output/.capy-appimage-package" ]]; then
    echo "Refusing to replace an unmarked AppImage package directory: $output" >&2
    exit 1
fi
rm -rf "$output"
mkdir -p "$output"
touch "$output/.capy-appimage-package"
version=$(sed -n 's/^version = "\(.*\)"$/\1/p' Cargo.toml)
runtime="$state/appimage-runtime-x86_64"
curl --fail --location --retry 3 -o "$runtime" \
    https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64
echo "2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d  $runtime" | sha256sum --check -
appdir="$state/AppDir"
rm -rf "$appdir" "$state/appimage.squashfs"
mkdir -p "$appdir/usr"
cp -a "$state/app/files/." "$appdir/usr/"
flatpak build --filesystem="$root" --filesystem="$state" --env="PATH=$state/cargo/build-tools/bin:/usr/bin" \
    "$state/app" bash "$root/packaging/appimage/bundle.sh" "$appdir"
install -m 755 packaging/appimage/AppRun "$appdir/AppRun"
cp "$appdir/usr/share/applications/art.capycanvas.CapyCanvas.desktop" "$appdir/"
cp "$appdir/usr/share/icons/hicolor/scalable/apps/art.capycanvas.CapyCanvas.svg" "$appdir/"
ln -s art.capycanvas.CapyCanvas.svg "$appdir/.DirIcon"
mksquashfs "$appdir" "$state/appimage.squashfs" -root-owned -noappend -comp zstd -quiet
package="$output/capycanvas-$version-linux-x86_64.AppImage"
cat "$runtime" "$state/appimage.squashfs" > "$package"
chmod 755 "$package"
