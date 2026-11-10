#!/bin/bash
# Redraws the Pixel Quest art and writes it into Sources/islo/PixelArt.swift.
# Needs python3 with Pillow and numpy.
#
#   tools/pixelart/regenerate.sh          terrain, places, ship and eagle (art2.py, art3.py)
#   tools/pixelart/regenerate.sh --cut    also re-cut the characters from characters-source.png
set -euo pipefail
cd "$(dirname "$0")"
SWIFT=../../Sources/islo/PixelArt.swift
MARK="/// The land and the landmarks in one sheet"
mkdir -p out
[ "${1:-}" = "--cut" ] && python3 cut.py
python3 art3.py
line=$(grep -n "$MARK" "$SWIFT" | head -1 | cut -d: -f1)
[ -n "$line" ] || { echo "marker not found in $SWIFT" >&2; exit 1; }
{ cat PixelArtData3.txt; echo; tail -n +"$line" "$SWIFT"; } > out/PixelArt.swift
mv out/PixelArt.swift "$SWIFT"
for f in art2.png art3.png tiling.png cut.png places.png; do [ -f "$f" ] && mv -f "$f" out/; done
rm -f PixelArtData2.txt PixelArtData3.txt
echo "wrote $SWIFT"
