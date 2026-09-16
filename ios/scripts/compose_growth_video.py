#!/usr/bin/env python3
"""Export authentic captured gameplay as Apple previews and social clips.

Requires ffmpeg, ffprobe, and Pillow. No gameplay is synthesized or sped up.
App previews use normal-speed cuts; social clips add typography around footage.
Simulator video has no audio, so Apple exports include an explicit silent stereo
AAC track. This is documented rather than presented as recorded game sound.
"""
import argparse
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont


FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REGULAR = "/System/Library/Fonts/Supplemental/Arial.ttf"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def probe(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)
    ]))


def encode_apple(source, destination, width, height, start=0, duration=None):
    args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", str(start), "-i", source,
            "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
    if duration:
        args += ["-t", str(duration)]
    args += ["-vf", f"scale={width}:{height}:force_original_aspect_ratio=decrease:force_divisible_by=2,"
             f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=0x0F0D23,setsar=1,fps=30",
             "-map", "0:v:0", "-map", "1:a:0", "-c:v", "libx264", "-preset", "fast",
             "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M", "-profile:v", "high",
             "-level:v", "4.0", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k",
             "-ac", "2", "-ar", "48000", "-shortest", "-movflags", "+faststart", "-y", destination]
    run(*args)


def social_background(path, title, subline):
    image = Image.new("RGB", (1080, 1920), "#0F0D23")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((56, 48, 67, 76), radius=4, fill="#90F0D2")
    draw.text((84, 46), "PRISM ROLL", font=ImageFont.truetype(FONT, 29), fill="#E6DFFF")
    draw.multiline_text((54, 109), title, font=ImageFont.truetype(FONT, 70), fill="white", spacing=0)
    draw.text((56, 269), subline, font=ImageFont.truetype(REGULAR, 30), fill="#BDB7D2")
    draw.rectangle((177, 324, 903, 1892), fill="#675A89")
    image.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    (root / "validation").mkdir(parents=True, exist_ok=True)
    video = root / "video"
    for folder in ("app-store", "social", "web", "segments"):
        (video / folder).mkdir(parents=True, exist_ok=True)
    # The first solve is shown in full; subsequent normal-speed excerpts show
    # richer boards, a perfect solve celebration, and the daily challenge.
    segments = [("perfect-route.mov", .8, 10.2), ("satisfying-solve.mov", 8, 10),
                ("daily-challenge.mov", 11.8, 6)]
    concat = []
    for index, (name, start, duration) in enumerate(segments):
        target = video / "segments" / f"{index:02d}.mp4"
        encode_apple(video / "raw" / name, target, 886, 1920, start, duration)
        concat.append(f"file '{target}'")
    concat_file = video / "segments" / "concat.txt"
    concat_file.write_text("\n".join(concat) + "\n")
    preview = video / "app-store" / "prism-roll-iphone-preview.mp4"
    run("ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", concat_file,
        "-c", "copy", "-movflags", "+faststart", "-y", preview)
    encode_apple(video / "raw" / "ipad-satisfying-solve.mov",
                 video / "app-store" / "prism-roll-ipad-preview.mp4", 1200, 1600, .6, 17.4)
    social = [
        ("satisfying-solve", "One maze.\nEvery tile.", "Find your flow, one swipe at a time."),
        ("perfect-route", "Can you match\n8 moves?", "A real perfect solve. Your turn."),
        ("daily-challenge", "Today's maze.\nYour next challenge.", "One fresh puzzle, every day."),
    ]
    outputs = [preview, video / "app-store" / "prism-roll-ipad-preview.mp4"]
    for name, title, subline in social:
        source = video / "raw" / f"{name}.mov"
        background = video / "social" / f"{name}-background.png"
        social_background(background, title, subline)
        output = video / "social" / f"{name}.mp4"
        duration = min(float(probe(source)["format"]["duration"]), 20)
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-loop", "1", "-i", background, "-i", source,
            "-filter_complex", "[1:v]scale=720:-2,fps=30,setsar=1[game];[0:v][game]overlay=180:327:shortest=1,fps=30[out]",
            "-map", "[out]", "-t", duration, "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-y", output)
        poster = video / "social" / f"{name}-poster.jpg"
        poster_time = "17" if name == "daily-challenge" else "5"
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", poster_time, "-i", output,
            "-frames:v", "1", "-update", "1", "-y", poster)
        outputs.append(output)
    manifest = []
    for path in outputs:
        info = probe(path)
        manifest.append({"file": str(path), "format": info["format"], "streams": info["streams"]})
    (root / "validation" / "video-probe.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for path in outputs:
        print(path)


if __name__ == "__main__":
    main()
