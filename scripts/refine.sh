#!/usr/bin/env bash
# Technical refinement pass for the Chili Labs reel (Video 1).
# Video 2 (wetracked.io reel) is used only as a look/delivery benchmark:
# it is a different speaker, set and script, so nothing is transferred from it
# except restrained tonal targets and the Reels delivery spec.
set -euo pipefail
IN="${1:?usage: refine.sh <input.mp4> <output.mp4>}"
OUT="${2:?usage: refine.sh <input.mp4> <output.mp4>}"

# Video chain:
#  hqdn3d      - light temporal denoise to calm AI texture crawl/shimmer on skin,
#                hair and walls (spatial kept low so detail is preserved)
#  eq          - restrained grade toward the reference: slightly deeper mids,
#                a touch more contrast and saturation (no hue shifts, so the
#                purple brand graphics are kept intact)
#  colorbalance- neutralise the slight warm cast in highlights only
VF="hqdn3d=1.0:0.8:3.0:2.5,\
eq=contrast=1.04:gamma=0.97:saturation=1.08,\
colorbalance=rh=-0.015:bh=0.015,\
scale=1080:1920:flags=lanczos,format=yuv420p,\
setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv"

# Audio: two-pass EBU R128 normalisation to -14 LUFS, true peak <= -1 dBTP.
read -r I TP LRA THRESH OFFSET < <(ffmpeg -hide_banner -nostats -i "$IN" \
  -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 |
  python3 -c 'import sys,json,re; d=json.loads(re.search(r"\{[^{}]*\}",sys.stdin.read()).group());print(d["input_i"],d["input_tp"],d["input_lra"],d["input_thresh"],d["target_offset"])')
AF="loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=$I:measured_TP=$TP:measured_LRA=$LRA:measured_thresh=$THRESH:offset=$OFFSET:linear=true,aresample=48000"

ffmpeg -hide_banner -y -i "$IN" \
  -vf "$VF" -r 30 \
  -c:v libx264 -profile:v high -level 4.2 -preset slow \
  -b:v 12M -maxrate 16M -bufsize 24M -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -af "$AF" -c:a aac -b:a 320k -ar 48000 -ac 2 \
  -movflags +faststart "$OUT"
