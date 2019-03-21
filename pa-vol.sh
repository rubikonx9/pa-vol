#!/bin/bash

# CHANGES, RE-VIEWS/WRITES, IMPROVEMENTS:
# mhasko: functions; VOL-steps;
# gashapon: autodectect default sink
# konrad: more reliable way to autodetect default sink
# rubikonx9: applied shellcheck, added dunst notifications

# get default sink name
SINK_NAME=$(pacmd dump | perl -a -n -e 'print $F[1] if /set-default-sink/')
# try this line instead of the one above if you got problems with the detection of your default sink.
#SINK_NAME=$(pactl stat | grep "alsa_output" | perl -a -n -e 'print $F[2]')
SOURCE_NAME=$(pacmd dump | perl -a -n -e 'print $F[1] if /set-default-source/')

# set max allowed volume; 0x10000 = 100%
VOL_MAX="0x10000"

STEPS="16" # 2^n
VOL_STEP=$((VOL_MAX / STEPS))

DUNST_MSG_ID=67818858

# Sets: $VOL_NOW, $MUTE_STATE
function read_volume() {
        VOL_NOW=$(pacmd dump | grep -P "^set-sink-volume $SINK_NAME\s+" | perl -p -n -e 's/.+\s(.x.+)$/$1/')
        MUTE_STATE=$(pacmd dump | grep -P "^set-sink-mute $SINK_NAME\s+" | perl -p -n -e 's/.+\s(yes|no)$/$1/')
        # Unsed as of now...
        # MIC_MUTE_STATE=`pacmd dump | grep -P "^set-source-mute $SINK_NAME\s+" | perl -p -n -e 's/.+\s(yes|no)$/$1/'`
}

function plus() {
        VOL_NEW=$((VOL_NOW + VOL_STEP))

        if [ $VOL_NEW -gt $((VOL_MAX)) ]; then
                VOL_NEW=$((VOL_MAX))
        fi

        pactl set-sink-volume "$SINK_NAME" "$(printf "0x%X" $VOL_NEW)"
}

function minus() {
        VOL_NEW=$((VOL_NOW - VOL_STEP))

        if [ "$VOL_NEW" -lt $((0x00000)) ]; then
                VOL_NEW=$((0x00000))
        fi

        pactl set-sink-volume "$SINK_NAME" "$(printf "0x%X" $VOL_NEW)"
}

function mute() {
        pactl set-sink-mute "$SINK_NAME" toggle
}

function micmute() {
        pactl set-source-mute "$SOURCE_NAME" toggle
}

# Sets: $BAR
function make_bar() {
        BAR=""
        if [ "$MUTE_STATE" = "yes" ]; then
                BAR="mute"
                ITERATOR=$((STEPS / 2 - 2))
                while [ $ITERATOR -gt 0 ]; do
                        BAR=" ${BAR} "
                        ITERATOR=$((ITERATOR - 1))
                done
        else
                DENOMINATOR=$((VOL_MAX / STEPS))
                LINES=$((VOL_NOW / DENOMINATOR))
                DOTS=$((STEPS - LINES))
                while [ $LINES -gt 0 ]; do
                        BAR="${BAR}|"
                        LINES=$((LINES - 1))
                done
                while [ $DOTS -gt 0 ]; do
                        BAR="${BAR}."
                        DOTS=$((DOTS - 1))
                done
        fi
}

function print() {
        echo "$BAR"
}

function notify() {
        command -v dunstify >/dev/null 2>&1 || {
                return
        }

        read_volume
        make_bar

        dunstify -a "change_volume"   \
                 -u normal            \
                 -i "audio-speakers"  \
                 -r "${DUNST_MSG_ID}" \
                 "${BAR}"
}

read_volume

case "$1" in
        plus)
                plus
                notify
        ;;

        minus)
                minus
                notify
        ;;

        mute)
                mute
                notify
        ;;

        get)
                make_bar
                print
        ;;

        micmute)
                micmute
                notify
        ;;

        *)
                make_bar
                print
        ;;
esac

