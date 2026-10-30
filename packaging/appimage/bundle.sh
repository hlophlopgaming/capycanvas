#!/usr/bin/env bash
set -euo pipefail
appdir=$1
lib="$appdir/usr/lib/capycanvas/gtk"
host='^(ld-linux-x86-64|libc|libm|libdl|libpthread|librt|libresolv|libutil|libanl|libmvec|libgcc_s|libstdc\+\+|libGL|libGLX|libGLdispatch|libOpenGL|libEGL|libGLESv2|libgbm|libdrm|libvulkan|libwayland-(client|cursor|egl|server)|libxcb|libX11|libfontconfig)(\.so|[-_])'
mapfile -t elves < <(find /app/bin /app/lib -type f -exec sh -c 'head -c 4 "$1" | grep -q ELF' _ {} \; -print)
resolved=$(ldd "${elves[@]}")
if grep -F 'not found' <<< "$resolved"; then exit 1; fi
awk '$2 == "=>" && $3 ~ /^\// && $3 !~ /^\/app\// {print $1, $3}' <<< "$resolved" | sort -u |
while read -r name path; do
    [[ $name =~ $host ]] && continue
    cp -L "$path" "$lib/$name"
    chmod 644 "$lib/$name"
    patchelf --set-rpath '$ORIGIN' "$lib/$name"
done
schemas="$appdir/usr/share/glib-2.0/schemas"
mkdir -p "$schemas"
cp /usr/share/glib-2.0/schemas/org.gtk.gtk4.*.gschema.xml "$schemas/"
glib-compile-schemas --strict "$schemas"
missing=0
while IFS= read -r -d '' elf; do
    head -c 4 "$elf" | grep -q ELF || continue
    for needed in $(readelf -d "$elf" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
        [[ $needed =~ $host || -e "$lib/$needed" ]] && continue
        echo "$elf needs $needed, which is neither bundled nor provided by the host" >&2
        missing=1
    done
done < <(find "$appdir/usr" -type f -print0)
exit "$missing"
