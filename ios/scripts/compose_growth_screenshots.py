#!/usr/bin/env python3
"""Frame authentic simulator captures with App Store marketing typography.

Requires Pillow. Screens remain unmodified apart from proportional scaling and
rounded outer corners. Source PNGs and export dimensions stay in the manifest.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont


SHOTS = [
    ("01-paint", "Paint every\ntile", "Swipe. Roll. Find your flow.", "#90F0D2"),
    ("02-perfect", "Find the\nperfect route", "A shortest-path challenge in every maze.", "#F9D58B"),
    ("03-daily", "A fresh challenge\nevery day", "One daily maze. A new reason to play.", "#AE9CFF"),
    ("04-timed", "Beat the clock", "Keep rolling through Time Rush.", "#90F0D2"),
    ("05-world", "Change the\nscenery", "Four worlds. Your favorite way to play.", "#F9D58B"),
    ("06-collection", "Make it\nyour own", "Earn coins. Collect colorful balls.", "#AE9CFF"),
]
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REGULAR = "/System/Library/Fonts/Supplemental/Arial.ttf"


def font(size, bold=True):
    return ImageFont.truetype(FONT if bold else REGULAR, int(size))


def background(width, height):
    # Smooth dusk tones taken from the app's existing violet visual language.
    small = Image.new("RGB", (width // 4, height // 4))
    pixels = small.load()
    for y in range(small.height):
        for x in range(small.width):
            glow = math.exp(-(((x / small.width - .8) / .8) ** 2 +
                              ((y / small.height - .65) / .55) ** 2) * 2)
            pixels[x, y] = (int(15 + 26 * glow), int(13 + 22 * glow), int(35 + 62 * glow))
    return small.resize((width, height), Image.Resampling.BICUBIC).convert("RGBA")


def compose(source, output, shot, family):
    width, height = (1320, 2868) if family == "iphone" else (2064, 2752)
    name, title, subline, accent = shot
    canvas = background(width, height)
    draw = ImageDraw.Draw(canvas)
    left = 112 if family == "iphone" else 155
    top = 74 if family == "iphone" else 90
    brand_size = 32 if family == "iphone" else 40
    draw.rounded_rectangle((left, top, left + 12, top + brand_size), radius=5, fill=accent)
    draw.text((left + 30, top - 2), "PRISM ROLL", font=font(brand_size), fill="#E6DFFF")
    title_size = 116 if family == "iphone" else 140
    title_font = font(title_size)
    title_y = 162 if family == "iphone" else 195
    while max(draw.textlength(line, font=title_font) for line in title.splitlines()) > width - 2 * left:
        title_size -= 1
        title_font = font(title_size)
    draw.multiline_text((left - 4, title_y), title, font=title_font,
                        fill="#FFFFFF", spacing=4, stroke_width=0)
    subline_y = 452 if family == "iphone" else 535
    subline_font = font(41 if family == "iphone" else 47, False)
    draw.text((left, subline_y), subline, font=subline_font, fill="#BDB7D2")
    image = Image.open(source).convert("RGB")
    shot_width = 1034 if family == "iphone" else 1510
    shot_height = round(image.height * shot_width / image.width)
    image = image.resize((shot_width, shot_height), Image.Resampling.LANCZOS)
    x, y = (width - shot_width) // 2, (height - shot_height - 66)
    radius = 76 if family == "iphone" else 44
    shadow = Image.new("RGBA", canvas.size)
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x - 15, y + 12, x + shot_width + 15, y + shot_height + 35),
                                 radius=radius + 18, fill=(0, 0, 0, 180))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(35)))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x - 5, y - 5, x + shot_width + 5, y + shot_height + 5),
                           radius=radius + 4, fill="#675A89")
    mask = Image.new("L", image.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot_width, shot_height), radius=radius, fill=255)
    canvas.paste(image, (x, y), mask)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output, quality=98, subsampling=0)
    return {"file": str(output), "source": str(source), "width": width, "height": height,
            "headline": title.replace("\n", " "), "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    manifest = []
    for family in ("iphone", "ipad"):
        for shot in SHOTS:
            source = args.root / "screenshots" / "raw" / family / (shot[0] + ".png")
            if source.exists():
                output = args.root / "screenshots" / family / (shot[0] + ".jpg")
                manifest.append(compose(source, output, shot, family))
    (args.root / "screenshots" / "composition-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    previews = []
    for entry in manifest:
        image = Image.open(entry["file"])
        image.thumbnail((264, 574), Image.Resampling.LANCZOS)
        previews.append(image)
    if previews:
        sheet = Image.new("RGB", (264 * min(6, len(previews)), 574 * math.ceil(len(previews) / 6)), "#0F0D23")
        for i, image in enumerate(previews):
            sheet.paste(image, ((i % 6) * 264, (i // 6) * 574))
        sheet.save(args.root / "screenshots" / "contact-sheet.jpg", quality=94)
    print(f"Composed {len(manifest)} screenshots")


if __name__ == "__main__":
    main()
