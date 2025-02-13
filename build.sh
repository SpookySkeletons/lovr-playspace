#!/bin/bash

if [ ! -f "$(dirname "$0")/lovr-x86_64.AppImage" ]; then
    echo "Error: lovr-x86_64.AppImage not found!"
    echo "Please download a LÖVR AppImage from https://github.com/bjornbytes/lovr/actions and save it as lovr-x86_64.AppImage in this repository"
    exit 1
fi

rm -f playspace.lovr && zip -9qr playspace.lovr json/json.lua conf.lua main.lua

rm -rf build && mkdir build && cp playspace.lovr lovr-playspace.sh lovr-x86_64.AppImage build/

tar -czf "lovr-playspace-$(git describe --tags --abbrev=0).tar.gz" -C build/ .
