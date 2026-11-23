#!/usr/bin/env python3
"""Generate three App Store screenshots and their Dynamic Island previews."""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ARTWORK_SCRIPT = ROOT / "Scripts" / "generate-app-store-artwork.py"
SCREEN_DIR = ROOT / "Docs" / "AppStoreScreenshots" / "Screenshots"
PREVIEW_DIR = ROOT / "Docs" / "AppStoreScreenshots" / "Previews"

WIDTH = 1290
HEIGHT = 2796
BLACK = (0, 0, 0, 255)
SURFACE = (20, 20, 22, 255)
WHITE = (255, 255, 255, 255)
SOFT_WHITE = (218, 218, 221, 255)
MUTED_WHITE = (157, 157, 163, 255)
FAINT_WHITE = (104, 104, 110, 255)
LINE = (255, 255, 255, 34)
CHINA_RED = (198, 12, 32, 255)
BRIGHT_RED = (224, 27, 45, 255)
AMBER = (255, 176, 0, 255)


def load_artwork_module():
    spec = importlib.util.spec_from_file_location("anddle_artwork", ARTWORK_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load artwork helpers from {ARTWORK_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


art = load_artwork_module()


def sf(size: int, weight: str = "Regular"):
    return art.sf(size, weight)


def cn(size: int, weight: str = "W6"):
    return art.cn(size, weight)


def text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    value: str,
    font,
    fill=WHITE,
    anchor: str | None = None,
) -> None:
    draw.text(xy, value, font=font, fill=fill, anchor=anchor)


def canvas() -> Image.Image:
    return Image.new("RGBA", (WIDTH, HEIGHT), BLACK)


def flatten(image: Image.Image) -> Image.Image:
    """Bake semi-transparent drawing colors over the black screen."""
    base = Image.new("RGBA", image.size, BLACK)
    return Image.alpha_composite(base, image).convert("RGB")


def draw_dynamic_island(draw: ImageDraw.ImageDraw) -> None:
    # iPhone 15 Pro Max style status area.
    text(draw, (78, 52), "9:41", sf(33, "Semibold"), WHITE)

    island = (464, 30, 826, 126)
    draw.rounded_rectangle(island, radius=48, fill=(3, 3, 4, 255))
    draw.rounded_rectangle(
        island,
        radius=48,
        outline=(48, 48, 52, 210),
        width=2,
    )
    draw.ellipse((770, 59, 799, 88), fill=(17, 18, 22, 255))
    draw.ellipse((780, 68, 789, 77), fill=(9, 25, 39, 255))

    # Signal
    for index, height in enumerate((18, 26, 34, 42)):
        x = 1036 + index * 17
        draw.rounded_rectangle(
            (x, 94 - height, x + 10, 94),
            radius=3,
            fill=WHITE,
        )
    # Wi-Fi
    for radius, width in ((40, 6), (27, 6), (15, 6)):
        draw.arc(
            (
                1088 - radius,
                83 - radius // 2,
                1088 + radius,
                83 + radius,
            ),
            start=210,
            end=330,
            fill=WHITE,
            width=width,
        )
    draw.ellipse((1082, 85, 1095, 98), fill=WHITE)

    # Battery
    draw.rounded_rectangle(
        (1140, 60, 1221, 95),
        radius=10,
        outline=WHITE,
        width=4,
    )
    draw.rounded_rectangle((1148, 68, 1205, 87), radius=5, fill=WHITE)
    draw.rounded_rectangle((1225, 71, 1232, 84), radius=3, fill=WHITE)


def draw_home_indicator(draw: ImageDraw.ImageDraw) -> None:
    draw.rounded_rectangle(
        (462, 2738, 828, 2748),
        radius=5,
        fill=(255, 255, 255, 235),
    )


def draw_plus(draw: ImageDraw.ImageDraw, x: int, y: int, size: int = 26, color=WHITE) -> None:
    draw.rounded_rectangle((x - size, y - 3, x + size, y + 3), radius=3, fill=color)
    draw.rounded_rectangle((x - 3, y - size, x + 3, y + size), radius=3, fill=color)


def draw_chevron_down(draw: ImageDraw.ImageDraw, x: int, y: int, color=WHITE) -> None:
    draw.line((x - 18, y - 8, x, y + 10), fill=color, width=5)
    draw.line((x, y + 10, x + 18, y - 8), fill=color, width=5)


def draw_gear(draw: ImageDraw.ImageDraw, x: int, y: int, color=WHITE) -> None:
    draw.ellipse((x - 22, y - 22, x + 22, y + 22), outline=color, width=4)
    draw.ellipse((x - 8, y - 8, x + 8, y + 8), outline=color, width=4)
    for angle in range(0, 360, 45):
        radians = math.radians(angle)
        x1 = x + math.cos(radians) * 27
        y1 = y + math.sin(radians) * 27
        x2 = x + math.cos(radians) * 35
        y2 = y + math.sin(radians) * 35
        draw.line((x1, y1, x2, y2), fill=color, width=5)


def draw_queue_icon(draw: ImageDraw.ImageDraw, x: int, y: int, color=WHITE) -> None:
    for offset, length in ((-16, 40), (0, 40), (16, 26)):
        draw.rounded_rectangle(
            (x - 24, y + offset - 2, x - 24 + length, y + offset + 2),
            radius=2,
            fill=color,
        )
    draw.ellipse((x + 9, y + 3, x + 29, y + 23), outline=color, width=4)
    draw.line((x + 28, y + 12, x + 28, y - 20), fill=color, width=4)
    draw.line((x + 28, y - 20, x + 39, y - 24), fill=color, width=4)


def draw_folder_icon(draw: ImageDraw.ImageDraw, x: int, y: int, color=SOFT_WHITE) -> None:
    draw.rounded_rectangle((x - 26, y - 18, x + 26, y + 22), radius=7, outline=color, width=4)
    draw.rounded_rectangle((x - 21, y - 28, x + 2, y - 14), radius=5, fill=color)


def draw_music_note(draw: ImageDraw.ImageDraw, x: int, y: int, color=FAINT_WHITE) -> None:
    draw.ellipse((x - 26, y + 10, x - 3, y + 30), fill=color)
    draw.rounded_rectangle((x - 7, y - 32, x - 1, y + 23), radius=3, fill=color)
    draw.polygon(
        [(x - 1, y - 33), (x + 30, y - 41), (x + 30, y - 24), (x - 1, y - 17)],
        fill=color,
    )


def draw_equalizer(draw: ImageDraw.ImageDraw, x: int, y: int, color=CHINA_RED) -> None:
    heights = (34, 58, 45, 26)
    for index, bar_height in enumerate(heights):
        bx = x - 31 + index * 19
        draw.rounded_rectangle(
            (bx, y + 26 - bar_height, bx + 9, y + 26),
            radius=4,
            fill=color,
        )


def draw_check_circle(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    selected: bool,
) -> None:
    radius = 23
    if selected:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=BRIGHT_RED)
        draw.line((x - 11, y, x - 2, y + 10), fill=BLACK, width=5)
        draw.line((x - 2, y + 10, x + 13, y - 10), fill=BLACK, width=5)
    else:
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            outline=FAINT_WHITE,
            width=3,
        )


def draw_pill(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    height: int,
    label: str,
    icon: str,
    accent: tuple[int, int, int, int] = CHINA_RED,
) -> None:
    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=height // 2,
        fill=(255, 255, 255, 20),
    )
    if icon == "moon":
        draw.ellipse((x + 25, y + 20, x + 57, y + 52), fill=accent)
        draw.ellipse((x + 35, y + 14, x + 65, y + 44), fill=BLACK)
    elif icon == "speed":
        cx, cy = x + 41, y + 37
        draw.arc((cx - 20, cy - 20, cx + 20, cy + 20), 180, 350, fill=accent, width=4)
        draw.line((cx, cy, cx + 12, cy - 9), fill=accent, width=4)
    text(draw, (x + 67, y + 17), label, sf(27, "Medium"), SOFT_WHITE)


def draw_library_row(
    draw: ImageDraw.ImageDraw,
    y: int,
    name: str,
    detail: str,
    kind: str,
    *,
    selected: bool | None = None,
    current: bool = False,
    progress: float = 0,
    duration: str | None = None,
) -> None:
    row_height = 210
    column_right = 150
    draw.rectangle((0, y, column_right, y + row_height), fill=(255, 255, 255, 8))
    draw.line((column_right, y, column_right, y + row_height), fill=(255, 255, 255, 18), width=2)
    draw.line((0, y + row_height, WIDTH, y + row_height), fill=LINE, width=2)

    if selected is not None:
        draw_check_circle(draw, 75, y + row_height // 2, selected)
    elif kind == "folder":
        draw_folder_icon(draw, 75, y + 89)
    elif current:
        draw_equalizer(draw, 75, y + 82)
    else:
        draw_music_note(draw, 75, y + 84)
        ext = name.rsplit(".", 1)[-1].upper()
        text(draw, (75, y + 143), ext, sf(18, "Semibold"), FAINT_WHITE, "ma")

    name_color = BRIGHT_RED if current else WHITE
    text(draw, (184, y + 48), name, cn(42, "W6"), name_color)
    if kind == "folder":
        text(draw, (185, y + 112), detail, cn(27, "W3"), FAINT_WHITE)
        return

    draw.rounded_rectangle(
        (184, y + 128, 430, y + 133),
        radius=3,
        fill=(255, 255, 255, 37),
    )
    if progress > 0:
        draw.rounded_rectangle(
            (184, y + 128, 184 + 246 * progress, y + 133),
            radius=3,
            fill=BRIGHT_RED,
        )
        knob_x = 184 + 246 * progress
        draw.ellipse((knob_x - 8, y + 122, knob_x + 8, y + 138), fill=WHITE)
    text(draw, (455, y + 115), detail, sf(24, "Regular"), FAINT_WHITE)
    if duration:
        text(draw, (1202, y + 112), duration, sf(24, "Regular"), FAINT_WHITE, "ra")


def draw_mini_player(draw: ImageDraw.ImageDraw, y: int) -> None:
    draw.rounded_rectangle((36, y, WIDTH - 36, y + 196), radius=30, fill=SURFACE)
    draw.rounded_rectangle((64, y + 30, 200, y + 166), radius=22, fill=CHINA_RED)
    draw.ellipse((98, y + 64, 166, y + 132), fill=(3, 3, 4, 255))
    text(draw, (226, y + 42), "夜航.m4a", cn(34, "W6"), WHITE)
    text(draw, (226, y + 104), "有声读物", cn(25, "W3"), MUTED_WHITE)
    draw.ellipse((1052, y + 47, 1158, y + 153), fill=BRIGHT_RED)
    draw.polygon(
        [(1086, y + 76), (1086, y + 124), (1128, y + 100)],
        fill=BLACK,
    )
    draw.rounded_rectangle(
        (36, y - 3, 36 + (WIDTH - 72) * 0.61, y + 3),
        radius=3,
        fill=BRIGHT_RED,
    )


def screenshot_library() -> Image.Image:
    image = canvas()
    art.add_background_glow(image, (1000, 230), 440)
    draw = ImageDraw.Draw(image)
    draw_dynamic_island(draw)

    text(draw, (58, 172), "音乐", cn(76, "W6"), WHITE)
    text(draw, (1008, 195), "选择", cn(31, "W3"), BRIGHT_RED)
    draw_plus(draw, 1190, 216, 22, WHITE)
    draw.line((0, 315, WIDTH, 315), fill=LINE, width=2)

    draw_library_row(
        draw,
        318,
        "有声读物",
        "2026-11-18  ·  8 个文件",
        "folder",
    )
    draw_library_row(
        draw,
        528,
        "古典音乐",
        "2026-11-16  ·  2 个文件夹",
        "folder",
    )
    draw_library_row(
        draw,
        738,
        "夜航.m4a",
        "03:12  ·  8.4 MB",
        "music",
        current=True,
        progress=0.67,
        duration="07:42",
    )
    draw_library_row(
        draw,
        948,
        "雨后的街道.mp3",
        "01:36  ·  5.1 MB",
        "music",
        progress=0.29,
        duration="05:18",
    )
    draw_library_row(
        draw,
        1158,
        "长篇小说·第三章.m4a",
        "05:08  ·  58.7 MB",
        "music",
        progress=0.12,
        duration="42:16",
    )
    draw_library_row(
        draw,
        1368,
        "钢琴练习.flac",
        "03:22  ·  24.3 MB",
        "music",
        progress=0.86,
        duration="03:54",
    )
    draw_library_row(
        draw,
        1578,
        "课程录音.wav",
        "18:42  ·  96.1 MB",
        "music",
        progress=0.38,
        duration="48:30",
    )
    draw_library_row(
        draw,
        1788,
        "清晨.aac",
        "01:11  ·  2.8 MB",
        "music",
        progress=0.53,
        duration="03:28",
    )
    draw_library_row(
        draw,
        1998,
        "练习曲.aiff",
        "00:42  ·  4.2 MB",
        "music",
        progress=0.34,
        duration="02:47",
    )
    draw_library_row(
        draw,
        2208,
        "片头音乐.caf",
        "--:--  ·  11.6 MB",
        "music",
        progress=0,
        duration="04:12",
    )

    draw_mini_player(draw, 2418)
    draw_home_indicator(draw)
    art.add_grain(image, 5)
    return flatten(image)


def draw_progress_bar(draw: ImageDraw.ImageDraw, y: int) -> None:
    draw.rounded_rectangle((78, y, 1212, y + 4), radius=2, fill=(255, 255, 255, 44))
    draw.rounded_rectangle((78, y, 820, y + 4), radius=2, fill=BRIGHT_RED)
    draw.ellipse((810, y - 10, 830, y + 14), fill=WHITE)
    text(draw, (78, y + 25), "03:12", sf(25, "Regular"), FAINT_WHITE)
    text(draw, (1212, y + 25), "-04:30", sf(25, "Regular"), FAINT_WHITE, "ra")
    text(draw, (78, y + 64), "02:55 / 1.10×", sf(22, "Regular"), (120, 120, 126, 255))
    text(draw, (1212, y + 64), "-04:06", sf(22, "Regular"), (120, 120, 126, 255), "ra")


def draw_player_controls(draw: ImageDraw.ImageDraw, y: int) -> None:
    # Shuffle
    draw.arc((124, y - 18, 192, y + 20), 200, 340, fill=FAINT_WHITE, width=5)
    draw.line((166, y - 20, 195, y - 20), fill=FAINT_WHITE, width=5)
    draw.line((195, y - 20, 186, y - 33), fill=FAINT_WHITE, width=5)
    draw.line((186, y - 20, 195, y - 7), fill=FAINT_WHITE, width=5)

    # Previous
    draw.rectangle((404, y - 24, 412, y + 24), fill=WHITE)
    draw.polygon([(460, y - 28), (460, y + 28), (414, y)], fill=WHITE)

    # Play/pause
    draw.ellipse((565, y - 76, 725, y + 84), fill=BRIGHT_RED)
    draw.rounded_rectangle((619, y - 29, 635, y + 31), radius=5, fill=BLACK)
    draw.rounded_rectangle((655, y - 29, 671, y + 31), radius=5, fill=BLACK)

    # Next
    draw.polygon([(830, y - 28), (830, y + 28), (876, y)], fill=WHITE)
    draw.rectangle((878, y - 24, 886, y + 24), fill=WHITE)

    # Repeat
    draw.arc((1082, y - 28, 1160, y + 22), 200, 20, fill=FAINT_WHITE, width=5)
    draw.polygon(
        [(1148, y - 28), (1165, y - 18), (1147, y - 8)],
        fill=FAINT_WHITE,
    )


def screenshot_now_playing() -> Image.Image:
    image = canvas()
    art.add_background_glow(image, (645, 820), 620)
    draw = ImageDraw.Draw(image)
    draw_dynamic_island(draw)

    # Top bar
    draw_chevron_down(draw, 92, 192)
    draw.rounded_rectangle((598, 178, 692, 187), radius=5, fill=(255, 255, 255, 76))
    draw.ellipse((1057, 183, 1083, 209), fill=BRIGHT_RED)
    draw_queue_icon(draw, 1137, 196)
    draw_gear(draw, 1217, 196)

    art.draw_vinyl(image, (645, 888), 1050, "有声读物")
    draw = ImageDraw.Draw(image)

    text(draw, (645, 1515), "长篇小说 · 第三章", cn(44, "W6"), WHITE, "ma")
    draw_pill(draw, 76, 1634, 270, 76, "15:00", "moon")
    draw_pill(draw, 944, 1634, 270, 76, "1.10×", "speed")
    draw_progress_bar(draw, 1814)
    draw_player_controls(draw, 2210)
    draw_home_indicator(draw)
    art.add_grain(image, 5)
    return flatten(image)


def screenshot_selection() -> Image.Image:
    image = canvas()
    draw = ImageDraw.Draw(image)
    draw_dynamic_island(draw)

    text(draw, (58, 172), "音乐", cn(76, "W6"), WHITE)
    text(draw, (1150, 194), "取消", cn(31, "W3"), BRIGHT_RED, "ra")
    draw.line((0, 315, WIDTH, 315), fill=LINE, width=2)

    draw_library_row(
        draw,
        318,
        "有声读物",
        "2026-11-18  ·  8 个文件",
        "folder",
        selected=True,
    )
    draw_library_row(
        draw,
        528,
        "古典音乐",
        "2026-11-16  ·  2 个文件夹",
        "folder",
        selected=False,
    )
    draw_library_row(
        draw,
        738,
        "夜航.m4a",
        "03:12  ·  8.4 MB",
        "music",
        selected=True,
        duration="07:42",
    )
    draw_library_row(
        draw,
        948,
        "雨后的街道.mp3",
        "01:36  ·  5.1 MB",
        "music",
        selected=False,
        duration="05:18",
    )
    draw_library_row(
        draw,
        1158,
        "长篇小说·第三章.m4a",
        "05:08  ·  58.7 MB",
        "music",
        selected=True,
        duration="42:16",
    )
    draw_library_row(
        draw,
        1368,
        "钢琴练习.flac",
        "03:22  ·  24.3 MB",
        "music",
        selected=False,
        duration="03:54",
    )
    draw_library_row(
        draw,
        1578,
        "课程录音.wav",
        "18:42  ·  96.1 MB",
        "music",
        selected=False,
        duration="48:30",
    )
    draw_library_row(
        draw,
        1788,
        "清晨.aac",
        "01:11  ·  2.8 MB",
        "music",
        selected=False,
        duration="03:28",
    )
    draw_library_row(
        draw,
        1998,
        "练习曲.aiff",
        "00:42  ·  4.2 MB",
        "music",
        selected=False,
        duration="02:47",
    )
    draw_library_row(
        draw,
        2208,
        "片头音乐.caf",
        "--:--  ·  11.6 MB",
        "music",
        selected=False,
        duration="04:12",
    )

    toolbar_top = 2426
    draw.rectangle((0, toolbar_top, WIDTH, HEIGHT), fill=SURFACE)
    draw.line((0, toolbar_top, WIDTH, toolbar_top), fill=LINE, width=2)
    text(draw, (162, toolbar_top + 64), "全选", cn(29, "W3"), BRIGHT_RED, "ma")
    text(draw, (440, toolbar_top + 64), "移动", cn(29, "W3"), BRIGHT_RED, "ra")
    draw.rounded_rectangle((458, toolbar_top + 48, 516, toolbar_top + 90), radius=21, fill=BRIGHT_RED)
    text(draw, (487, toolbar_top + 67), "3", sf(22, "Semibold"), BLACK, "mm")
    text(draw, (806, toolbar_top + 64), "重命名", cn(29, "W3"), FAINT_WHITE, "ma")
    text(draw, (1128, toolbar_top + 64), "删除", cn(29, "W3"), BRIGHT_RED, "ma")
    draw_home_indicator(draw)
    art.add_grain(image, 5)
    return flatten(image)


def rounded_screen(image: Image.Image, size: tuple[int, int], radius: int) -> Image.Image:
    resized = image.resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1),
        radius=radius,
        fill=255,
    )
    resized.putalpha(mask)
    return resized


def preview(
    screenshot: Image.Image,
    headline: str,
    subline: str,
    accent_center: tuple[int, int],
) -> Image.Image:
    image = Image.new("RGBA", (WIDTH, HEIGHT), BLACK)
    art.add_background_glow(image, accent_center, 760)
    draw = ImageDraw.Draw(image)

    icon = art.rounded_icon(74)
    image.alpha_composite(icon, (82, 76))
    text(draw, (178, 86), "AnddleMPlayer", sf(36, "Semibold"), WHITE)
    text(draw, (180, 137), "本地音乐播放器", cn(24, "W3"), MUTED_WHITE)

    headline_lines = headline.split("\n")
    y = 270
    for line in headline_lines:
        text(draw, (82, y), line, cn(96, "W6"), WHITE)
        y += 118
    text(draw, (86, y + 22), subline, cn(35, "W3"), SOFT_WHITE)

    phone_left, phone_top = 174, 720
    phone_width, phone_height = 942, 2040
    screen_left, screen_top = 195, 742
    screen_width, screen_height = 900, 1951

    # Soft drop shadow and titanium-like body.
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (
            phone_left - 14,
            phone_top + 18,
            phone_left + phone_width + 14,
            phone_top + phone_height + 40,
        ),
        radius=122,
        fill=(0, 0, 0, 220),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    image.alpha_composite(shadow)

    draw.rounded_rectangle(
        (phone_left, phone_top, phone_left + phone_width, phone_top + phone_height),
        radius=117,
        fill=(29, 29, 31, 255),
        outline=(104, 104, 108, 255),
        width=3,
    )
    draw.rounded_rectangle(
        (
            phone_left + 9,
            phone_top + 9,
            phone_left + phone_width - 9,
            phone_top + phone_height - 9,
        ),
        radius=108,
        fill=(4, 4, 5, 255),
        outline=(8, 8, 9, 255),
        width=3,
    )

    # Side buttons.
    draw.rounded_rectangle(
        (phone_left - 13, phone_top + 382, phone_left - 3, phone_top + 512),
        radius=6,
        fill=(111, 111, 115, 255),
    )
    draw.rounded_rectangle(
        (phone_left - 13, phone_top + 558, phone_left - 3, phone_top + 760),
        radius=6,
        fill=(111, 111, 115, 255),
    )
    draw.rounded_rectangle(
        (
            phone_left + phone_width + 3,
            phone_top + 610,
            phone_left + phone_width + 13,
            phone_top + 900,
        ),
        radius=6,
        fill=(111, 111, 115, 255),
    )

    screen = rounded_screen(screenshot, (screen_width, screen_height), 88)
    image.alpha_composite(screen, (screen_left, screen_top))

    # Thin reflection line across the outer frame.
    draw.line(
        (phone_left + 80, phone_top + 2, phone_left + phone_width - 80, phone_top + 2),
        fill=(218, 218, 222, 80),
        width=2,
    )

    art.add_grain(image, 6)
    return flatten(image)


def validate(image: Image.Image, path: Path) -> None:
    if image.size != (WIDTH, HEIGHT):
        raise RuntimeError(f"Unexpected dimensions for {path}: {image.size}")
    if image.mode != "RGB":
        raise RuntimeError(f"Unexpected mode for {path}: {image.mode}")
    if image.getextrema() == ((0, 0), (0, 0), (0, 0)):
        raise RuntimeError(f"Blank image generated for {path}")


def main() -> None:
    SCREEN_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    screens = [
        ("01-library", screenshot_library()),
        ("02-now-playing", screenshot_now_playing()),
        ("03-selection", screenshot_selection()),
    ]
    for name, image in screens:
        path = SCREEN_DIR / f"{name}-1290x2796.png"
        validate(image, path)
        image.save(path, "PNG", optimize=True)
        print(path)

    preview_specs = [
        (
            "01-library-preview",
            screens[0][1],
            "按文件夹整理\n你的音乐",
            "真实目录，清晰有序",
            (930, 1220),
        ),
        (
            "02-now-playing-preview",
            screens[1][1],
            "极简播放\n细节刚刚好",
            "黑胶、倍速与定时停止",
            (660, 980),
        ),
        (
            "03-selection-preview",
            screens[2][1],
            "选中、移动、删除\n井然有序",
            "文件管理，全在 App 内",
            (860, 1040),
        ),
    ]
    for name, screen, headline, subline, center in preview_specs:
        image = preview(screen, headline, subline, center)
        path = PREVIEW_DIR / f"{name}-1290x2796.png"
        validate(image, path)
        image.save(path, "PNG", optimize=True)
        print(path)


if __name__ == "__main__":
    main()
