#!/bin/bash
dir="$(dirname "$(readlink -f "$0")")"
"$dir/lovr-x86_64.AppImage" "$dir/playspace.lovr"
