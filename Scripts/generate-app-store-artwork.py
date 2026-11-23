#!/usr/bin/env python3
"""Generate the two App Store marketing images without external dependencies."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "Docs" / "AppStoreArtwork"
ICON_PATH = ROOT / "AnddleMPlayer" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"

TITLE_SIZE = (3840, 1646)
SEARCH_SIZE = (3840, 2560)
BLACK = (0, 0, 0, 255)
NEAR_BLACK = (10, 10, 11, 255)
WHITE = (255, 255, 255, 255)
SOFT_WHITE = (214, 214, 216, 255)
MUTED_WHITE = (153, 153, 158, 255)
FAINT_WHITE = (92, 92, 97, 255)
CHINA_RED = (198, 12, 32, 255)
BRIGHT_RED = (224, 27, 45, 255)
DARK_RED = (72, 5, 13, 255)

SF_PATH = "/System/Library/Fonts/SFNS.ttf"
CN_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def sf(size: int, weight: str = "Regular") -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(SF_PATH, size)
    font.set_variation_by_name(weight)
    return font


def cn(size: int, weight: str = "W6") -> ImageFont.FreeTypeFont:
    index = 2 if weight == "W6" else 0
    return ImageFont.truetype(CN_PATH, size, index=index)


def rounded_icon(size: int) -> Image.Image:
    icon = Image.open(ICON_PATH).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1),
        radius=size * 4 * 0.225,
        fill=255,
    )
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    rounded = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rounded.paste(icon, (0, 0), mask)
    return rounded


def cubic_bezier(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int = 100,
) -> list[tuple[float, float]]:
    result = []
    for index in range(steps + 1):
        t = index / steps
        u = 1.0 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        result.append((x, y))
    return result


def draw_stroke(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], color, width: int) -> None:
    draw.line(points, fill=color, width=width, joint="curve")
    radius = width / 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def add_background_glow(image: Image.Image, center: tuple[int, int], radius: int) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for index in range(18, 0, -1):
        r = int(radius * index / 18)
        alpha = int(2 + 18 * (1 - index / 18) ** 1.8)
        glow_draw.ellipse(
            (center[0] - r, center[1] - r, center[0] + r, center[1] + r),
            fill=(CHINA_RED[0], CHINA_RED[1], CHINA_RED[2], alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(95))
    image.alpha_composite(glow)


def add_grain(image: Image.Image, opacity: int = 6) -> None:
    rng = random.Random(20261123)
    width, height = image.size
    pixel_count = width * height
    noise = Image.frombytes(
        "L",
        (width, height),
        rng.randbytes(pixel_count),
    )
    noise_rgba = Image.new("RGBA", image.size, (255, 255, 255, 0))
    noise_rgba.putalpha(noise.point(lambda value: int(value * opacity / 255)))
    image.alpha_composite(noise_rgba)


def draw_vinyl(
    image: Image.Image,
    center: tuple[int, int],
    diameter: int,
    label_text: str,
    show_tonearm: bool = True,
) -> None:
    draw = ImageDraw.Draw(image)
    cx, cy = center
    radius = diameter / 2

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (
            cx - radius - 22,
            cy - radius + 28,
            cx + radius + 22,
            cy + radius + 70,
        ),
        fill=(0, 0, 0, 210),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(38))
    image.alpha_composite(shadow)

    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=CHINA_RED,
        outline=(246, 34, 50, 255),
        width=4,
    )

    # Uniform, deliberately visible grooves echo the in-app record.
    groove_start = int(diameter * 0.34)
    groove_end = int(diameter * 0.478)
    for groove_radius in range(groove_start, groove_end, 10):
        draw.ellipse(
            (
                cx - groove_radius,
                cy - groove_radius,
                cx + groove_radius,
                cy + groove_radius,
            ),
            outline=(61, 0, 8, 155),
            width=3,
        )

    label_radius = int(diameter * 0.265)
    draw.ellipse(
        (
            cx - label_radius,
            cy - label_radius,
            cx + label_radius,
            cy + label_radius,
        ),
        fill=(5, 5, 6, 255),
    )

    chars = list(label_text)
    if len(chars) > 6:
        split = math.ceil(len(chars) / 2)
        lines = ["".join(chars[:split]), "".join(chars[split:])]
    else:
        lines = [label_text]

    font_size = int(label_radius * (0.47 if len(lines) == 1 else 0.40))
    label_font = cn(font_size, "W6")
    y = cy - (len(lines) - 1) * font_size * 0.70
    for line in lines:
        box = draw.textbbox((0, 0), line, font=label_font)
        text_width = box[2] - box[0]
        draw.text(
            (cx - text_width / 2, y - font_size * 0.58),
            line,
            font=label_font,
            fill=WHITE,
        )
        y += font_size * 0.86

    draw.rounded_rectangle(
        (
            cx - label_radius * 0.16,
            cy + label_radius * 0.54,
            cx + label_radius * 0.16,
            cy + label_radius * 0.56,
        ),
        radius=2,
        fill=(255, 255, 255, 150),
    )
    draw.ellipse(
        (cx - 10, cy - 10, cx + 10, cy + 10),
        fill=DARK_RED,
        outline=(255, 255, 255, 190),
        width=2,
    )

    if not show_tonearm:
        return

    pivot = (cx + radius * 0.62, cy - radius * 0.72)
    # Land on the right-hand groove area so the arm does not obscure the
    # centered folder label in the marketing artwork.
    head = (cx + radius * 0.39, cy - radius * 0.11)
    first = (pivot[0] + 38, pivot[1] + 40)
    second = (head[0] + 150, head[1] - 115)
    arm = cubic_bezier(pivot, first, second, head, 140)

    arm_shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    arm_shadow_draw = ImageDraw.Draw(arm_shadow)
    draw_stroke(
        arm_shadow_draw,
        [(x + 6, y + 10) for x, y in arm],
        (0, 0, 0, 180),
        20,
    )
    arm_shadow = arm_shadow.filter(ImageFilter.GaussianBlur(8))
    image.alpha_composite(arm_shadow)

    draw = ImageDraw.Draw(image)
    draw_stroke(draw, arm, (0, 0, 0, 190), 22)
    draw_stroke(draw, arm, (246, 246, 247, 255), 10)

    draw.ellipse(
        (pivot[0] - 54, pivot[1] - 54, pivot[0] + 54, pivot[1] + 54),
        fill=(40, 2, 7, 255),
        outline=(255, 255, 255, 110),
        width=2,
    )
    draw.ellipse(
        (pivot[0] - 35, pivot[1] - 35, pivot[0] + 35, pivot[1] + 35),
        fill=(235, 235, 237, 255),
    )
    draw.ellipse(
        (pivot[0] - 9, pivot[1] - 9, pivot[0] + 9, pivot[1] + 9),
        fill=BRIGHT_RED,
    )
    draw.rounded_rectangle(
        (head[0] - 18, head[1] - 33, head[0] + 18, head[1] + 33),
        radius=14,
        fill=(27, 3, 7, 255),
        outline=(255, 255, 255, 90),
        width=2,
    )
    draw.rounded_rectangle(
        (head[0] - 3, head[1] - 25, head[0] + 3, head[1] + 15),
        radius=3,
        fill=(255, 255, 255, 200),
    )


def text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    value: str,
    font: ImageFont.FreeTypeFont,
    fill=WHITE,
    anchor: str | None = None,
) -> None:
    draw.text(xy, value, font=font, fill=fill, anchor=anchor)


def draw_brand(
    image: Image.Image,
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    icon_size: int,
    name_size: int,
    subtitle_size: int,
) -> None:
    icon = rounded_icon(icon_size)
    image.alpha_composite(icon, (x, y))
    text_x = x + icon_size + 42
    text(draw, (text_x, y + 3), "AnddleMPlayer", sf(name_size, "Semibold"), WHITE)
    text(
        draw,
        (text_x + 4, y + name_size + 20),
        "本地音乐播放器",
        cn(subtitle_size, "W3"),
        (187, 187, 191, 255),
    )


def draw_feature_pill(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    label: str,
) -> None:
    height = 92
    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=height // 2,
        fill=(13, 13, 14, 235),
        outline=(255, 255, 255, 35),
        width=2,
    )
    draw.ellipse((x + 34, y + 39, x + 48, y + 53), fill=BRIGHT_RED)
    text(draw, (x + 68, y + 18), label, cn(34, "W6"), WHITE)


def build_title_artwork() -> Image.Image:
    width, height = TITLE_SIZE
    image = Image.new("RGBA", (width, height), BLACK)
    add_background_glow(image, (2960, 790), 1040)
    draw = ImageDraw.Draw(image)

    # Faint rings extend the record language into the background.
    for radius in (900, 1010, 1120):
        draw.ellipse(
            (2960 - radius, 800 - radius, 2960 + radius, 800 + radius),
            outline=(218, 24, 44, 14),
            width=3,
        )

    draw_brand(image, draw, 238, 128, 166, 92, 39)

    text(draw, (250, 426), "本地音乐", cn(218, "W6"), WHITE)
    text(draw, (250, 681), "简洁播放", cn(218, "W6"), WHITE)
    text(
        draw,
        (260, 1010),
        "文件与文件夹，按你的方式整理",
        cn(62, "W3"),
        SOFT_WHITE,
    )

    draw_feature_pill(draw, 260, 1162, 380, "多选导入")
    draw_feature_pill(draw, 692, 1162, 380, "倍速播放")
    draw_feature_pill(draw, 1124, 1162, 380, "断点续播")

    text(
        draw,
        (260, 1405),
        "只播放你真正拥有的音乐",
        cn(48, "W3"),
        MUTED_WHITE,
    )

    draw_vinyl(image, (2960, 800), 1190, "我的音乐")
    add_grain(image, 7)
    return image.convert("RGB")


def draw_music_row(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    title: str,
    extension: str,
    progress: float,
    active: bool = False,
) -> None:
    row_height = 232
    if active:
        draw.rounded_rectangle(
            (x - 22, y - 14, x + width + 22, y + row_height - 12),
            radius=42,
            fill=(24, 9, 13, 255),
            outline=(198, 12, 32, 110),
            width=3,
        )

    icon_side = 144
    icon_y = y + 40
    draw.rounded_rectangle(
        (x, icon_y, x + icon_side, icon_y + icon_side),
        radius=30,
        fill=(26, 26, 28, 255),
        outline=(255, 255, 255, 24),
        width=3,
    )
    draw.ellipse(
        (x + 36, icon_y + 39, x + 108, icon_y + 111),
        outline=(246, 246, 247, 255),
        width=5,
    )
    draw.ellipse((x + 64, icon_y + 67, x + 80, icon_y + 83), fill=BRIGHT_RED)
    draw.polygon(
        [
            (x + 101, icon_y + 25),
            (x + 119, icon_y + 20),
            (x + 119, icon_y + 86),
            (x + 108, icon_y + 94),
            (x + 99, icon_y + 88),
            (x + 99, icon_y + 31),
        ],
        fill=WHITE,
    )

    text_x = x + icon_side + 44
    text(draw, (text_x, y + 48), title, cn(48, "W6"), WHITE)
    text(draw, (text_x, y + 120), extension, sf(32, "Regular"), MUTED_WHITE)

    bar_left = text_x
    bar_right = x + width - 12
    bar_y = y + 192
    draw.rounded_rectangle(
        (bar_left, bar_y, bar_right, bar_y + 6),
        radius=3,
        fill=(255, 255, 255, 36),
    )
    fill_right = bar_left + (bar_right - bar_left) * progress
    if progress > 0:
        draw.rounded_rectangle(
            (bar_left, bar_y, fill_right, bar_y + 6),
            radius=3,
            fill=BRIGHT_RED,
        )


def build_search_result_artwork() -> Image.Image:
    width, height = SEARCH_SIZE
    image = Image.new("RGBA", (width, height), BLACK)
    add_background_glow(image, (1000, 1580), 920)
    draw = ImageDraw.Draw(image)

    draw_brand(image, draw, 218, 168, 150, 84, 36)

    text(draw, (218, 492), "打开就能", cn(194, "W6"), WHITE)
    text(draw, (218, 738), "继续听", cn(194, "W6"), BRIGHT_RED)
    text(draw, (226, 1010), "进度自动保存", cn(54, "W3"), SOFT_WHITE)

    draw_vinyl(image, (980, 1620), 980, "有声读物")

    draw_feature_pill(draw, 218, 2080, 340, "倍速播放")
    draw_feature_pill(draw, 592, 2080, 340, "定时停止")
    draw_feature_pill(draw, 966, 2080, 340, "断点续播")

    # The right side stays close to the real app: file-first list and mini player.
    panel_left = 1760
    panel_top = 180
    panel_right = 3630
    panel_bottom = 2360
    draw.rounded_rectangle(
        (panel_left, panel_top, panel_right, panel_bottom),
        radius=76,
        fill=(11, 11, 12, 246),
        outline=(255, 255, 255, 27),
        width=3,
    )

    text(draw, (1855, 286), "我的音乐", cn(78, "W6"), WHITE)
    draw.ellipse(
        (3448, 300, 3510, 362),
        fill=(20, 20, 21, 255),
        outline=(255, 255, 255, 45),
        width=2,
    )
    text(draw, (3479, 310), "+", sf(40, "Light"), WHITE, "ma")

    row_x = 1855
    row_width = 1670
    draw_music_row(draw, row_x, 438, row_width, "夜航", "M4A · 7:42", 0.67, active=True)
    draw_music_row(draw, row_x, 686, row_width, "雨后的街道", "MP3 · 5:18", 0.28)
    draw_music_row(draw, row_x, 934, row_width, "长篇小说 · 第三章", "M4A · 42:16", 0.12)
    draw_music_row(draw, row_x, 1182, row_width, "钢琴练习", "WAV · 3:54", 0.86)

    mini_left = 1820
    mini_top = 1570
    mini_right = 3570
    mini_bottom = 1900
    draw.rounded_rectangle(
        (mini_left, mini_top, mini_right, mini_bottom),
        radius=54,
        fill=(19, 19, 20, 252),
        outline=(255, 255, 255, 28),
        width=3,
    )
    draw.rounded_rectangle(
        (1854, mini_top + 47, 2020, mini_top + 213),
        radius=34,
        fill=CHINA_RED,
    )
    draw.ellipse(
        (1893, mini_top + 86, 1981, mini_top + 174),
        fill=(5, 5, 6, 255),
        outline=(255, 255, 255, 75),
        width=3,
    )
    text(draw, (2060, mini_top + 62), "夜航", cn(52, "W6"), WHITE)
    text(draw, (2060, mini_top + 138), "有声读物", cn(34, "W3"), MUTED_WHITE)
    draw.ellipse((3302, mini_top + 76, 3440, mini_top + 214), fill=BRIGHT_RED)
    draw.polygon(
        [
            (3348, mini_top + 108),
            (3348, mini_top + 182),
            (3404, mini_top + 145),
        ],
        fill=BLACK,
    )

    draw.rounded_rectangle(
        (1820, 2036, 3570, 2044),
        radius=4,
        fill=(255, 255, 255, 35),
    )
    draw.rounded_rectangle(
        (1820, 2036, 3008, 2044),
        radius=4,
        fill=BRIGHT_RED,
    )

    text(
        draw,
        (2695, 2178),
        "文件与文件夹  ·  倍速播放  ·  断点续播",
        cn(40, "W3"),
        SOFT_WHITE,
        "mm",
    )
    text(draw, (2695, 2252), "安安静静，好好听歌", cn(32, "W3"), FAINT_WHITE, "mm")

    add_grain(image, 7)
    return image.convert("RGB")


def validate(image: Image.Image, path: Path, expected_size: tuple[int, int]) -> None:
    if image.size != expected_size:
        raise RuntimeError(f"Unexpected dimensions for {path}: {image.size}")
    if image.mode != "RGB":
        raise RuntimeError(f"Unexpected mode for {path}: {image.mode}")
    if image.getextrema() == ((0, 0), (0, 0), (0, 0)):
        raise RuntimeError(f"Blank image generated for {path}")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = [
        (OUTPUT_DIR / "01-title-3840x1646.png", build_title_artwork(), TITLE_SIZE),
        (OUTPUT_DIR / "02-search-3840x2560.png", build_search_result_artwork(), SEARCH_SIZE),
    ]
    for path, image, expected_size in outputs:
        validate(image, path, expected_size)
        image.save(path, "PNG", optimize=True)
        print(path)


if __name__ == "__main__":
    main()
