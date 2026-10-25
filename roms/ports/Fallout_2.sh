#!/bin/sh

# 1. Path resolution
PORT_DIR="/storage/roms/ports/fallout2"
[ ! -d "$PORT_DIR" ] && PORT_DIR="/sdcard/roms/ports/fallout2"
[ ! -d "$PORT_DIR" ] && PORT_DIR="/mnt/sdcard/roms/ports/fallout2"

LOG="$PORT_DIR/fallout2.log"
echo "=== Starting Fallout 2 (fallout2-ce) at $(date) ===" > $LOG
echo "Kernel: $(uname -a 2>/dev/null)" >> $LOG
echo "[PATH CHECK] PORT_DIR=$PORT_DIR" >> $LOG
cd "$PORT_DIR" || { echo "[ERROR] Failed to cd to $PORT_DIR" >> $LOG; exit 1; }
echo "[PATH CHECK] Current working directory: $(pwd)" >> $LOG

# Auto-recombine split resource archives if present
if [ ! -f "$PORT_DIR/master.dat" ] && [ -f "$PORT_DIR/master.dat.partaa" ]; then
    echo "First launch: Recombining master.dat..." >> $LOG
    cat "$PORT_DIR"/master.dat.part* > "$PORT_DIR/master.dat"
    rm -f "$PORT_DIR"/master.dat.part*
fi
if [ ! -f "$PORT_DIR/critter.dat" ] && [ -f "$PORT_DIR/critter.dat.partaa" ]; then
    echo "First launch: Recombining critter.dat..." >> $LOG
    cat "$PORT_DIR"/critter.dat.part* > "$PORT_DIR/critter.dat"
    rm -f "$PORT_DIR"/critter.dat.part*
fi


# Ensure symlinks for fallout2 and gemrb for consistency
if [ "$PORT_DIR" != "/storage/roms/ports/fallout2" ] && [ ! -d "/storage/roms/ports/fallout2" ]; then
    mkdir -p /storage/roms/ports 2>/dev/null
    ln -sf "$PORT_DIR" /storage/roms/ports/fallout2 2>/dev/null
fi
if [ ! -d "/storage/roms/ports/gemrb" ]; then
    mkdir -p /storage/roms/ports 2>/dev/null
    [ -d "/sdcard/roms/ports/gemrb" ] && ln -sf /sdcard/roms/ports/gemrb /storage/roms/ports/gemrb 2>/dev/null
    [ -d "/mnt/sdcard/roms/ports/gemrb" ] && ln -sf /mnt/sdcard/roms/ports/gemrb /storage/roms/ports/gemrb 2>/dev/null
fi

# 2. Hardware Devices Verification
echo "[HARDWARE CHECK] Checking hardware device nodes:" >> $LOG
chmod 666 /dev/fb* /dev/graphics/fb* /dev/mali* /dev/ump /dev/dri/* /dev/input/* /dev/tty* /dev/uinput 2>/dev/null
echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null
[ -e /dev/fb0 ] && echo "  - Framebuffer /dev/fb0: OK" >> $LOG || echo "  - /dev/fb0: NOT FOUND" >> $LOG
[ -e /dev/mali0 ] && echo "  - Mali GPU node /dev/mali0: OK" >> $LOG || { [ -e /dev/mali ] && echo "  - Mali GPU node /dev/mali: OK" >> $LOG || echo "  - Mali GPU node: NOT FOUND" >> $LOG; }
[ -e /dev/mali ] && [ ! -e /dev/mali0 ] && ln -sf /dev/mali /dev/mali0 2>/dev/null
[ -e /dev/mali0 ] && [ ! -e /dev/mali ] && ln -sf /dev/mali0 /dev/mali 2>/dev/null
[ -e /dev/dri/card0 ] && echo "  - DRI node /dev/dri/card0: OK" >> $LOG || echo "  - DRI node /dev/dri/card0: NOT FOUND" >> $LOG

# 3. Kill previous mappers and launch dedicated M17 Fallout mapper
killall -9 m17_fallout_mapper 2>/dev/null
killall -9 m17_gemrb_mapper 2>/dev/null
killall -9 m17_diablo_mapper 2>/dev/null
sleep 1

MAPPER_PID=""
if [ -f "$PORT_DIR/m17_fallout_mapper" ]; then
    chmod +x "$PORT_DIR/m17_fallout_mapper" 2>/dev/null
    "$PORT_DIR/m17_fallout_mapper" >> $LOG 2>&1 &
    MAPPER_PID=$!
    echo "  - Started m17_fallout_mapper (PID $MAPPER_PID)" >> $LOG
    sleep 1
    chmod 666 /dev/input/* /dev/uinput 2>/dev/null
fi

# 4. Runtime Environment Configuration (Identical to Baldur's Gate)
export SDL_AUDIODRIVER=alsa
export AUDIODEV=default
export HOME="$PORT_DIR"
export FRAMEBUFFER=/dev/fb0
export SDL_VIDEODRIVER=mali
export SDL_VIDEO_GL_DRIVER="/storage/roms/ports/gemrb/libs/libGLESv2.so"
export SDL_VIDEO_EGL_DRIVER="/storage/roms/ports/gemrb/libs/libEGL.so"
export SDL_RENDER_SCALE_QUALITY=linear
export SDL_RENDER_LOGICAL_SIZE_MODE=letterbox
export SDL_FRAMEBUFFER_ACCELERATION=1

LIB_PATH="$PORT_DIR/libs:/storage/roms/ports/gemrb/libs:/storage/emuelec/lib32:/emuelec/lib32:/usr/lib:/lib"
PRELOAD_LIB="$PORT_DIR/libs/libsdl_compat.so"

chmod +x "$PORT_DIR/fallout2-ce" "$PORT_DIR/libs/ld-linux-armhf.so.3" 2>/dev/null

echo "[EXECUTION] Launching fallout2-ce via ld-linux-armhf.so.3..." >> $LOG
echo "SDL_VIDEODRIVER=$SDL_VIDEODRIVER GL=$SDL_VIDEO_GL_DRIVER EGL=$SDL_VIDEO_EGL_DRIVER" >> $LOG

if [ -f "$PORT_DIR/libs/ld-linux-armhf.so.3" ]; then
    "$PORT_DIR/libs/ld-linux-armhf.so.3" \
        --library-path "$LIB_PATH" \
        --preload "$PRELOAD_LIB" \
        "$PORT_DIR/fallout2-ce" >> $LOG 2>&1
else
    LD_LIBRARY_PATH="$LIB_PATH" LD_PRELOAD="$PRELOAD_LIB" "$PORT_DIR/fallout2-ce" >> $LOG 2>&1
fi

RET=$?
echo "[EXECUTION] fallout2-ce finished with exit code $RET" >> $LOG

[ -n "$MAPPER_PID" ] && kill -9 $MAPPER_PID 2>/dev/null
killall -9 m17_fallout_mapper 2>/dev/null

cp -f "$LOG" /sdcard/fallout2.log 2>/dev/null
sync
