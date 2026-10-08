#!/bin/bash
cd /home/claude/redux/squashfs-root
export XDG_RUNTIME_DIR=/tmp/xdg LD_LIBRARY_PATH=$PWD/usr/lib SDL_AUDIODRIVER=dummy LD_PRELOAD=/home/claude/redux/shim243.so
mkdir -p /tmp/xdg
timeout ${2:-240} usr/bin/pcsx-redux -cli -noupdate -interpreter -softgpu -debugger -fastboot -loadiso /home/claude/redux/game/naruto.cue -run -dofile "$1"
