from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "maps"
WIDTH = 960
HEIGHT = 640
CELL = 80


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def mix(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(lerp(a, b, t) for a, b in zip(c1, c2))


def draw_blade(draw: ImageDraw.ImageDraw, x: float, y: float, color: tuple[int, int, int, int]) -> None:
    sway = random.uniform(-3.0, 3.0)
    height = random.uniform(7.0, 13.0)
    draw.line((x, y, x + sway, y - height), fill=color, width=2)


def draw_bush(image: Image.Image, x: int, y: int, scale: float) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    outline = (45, 91, 48, 210)
    colors = [
        (75, 151, 72, 235),
        (92, 174, 82, 235),
        (58, 132, 66, 235),
    ]
    blobs = [
        (-13, 2, 12),
        (-2, -7, 15),
        (12, 1, 12),
        (0, 8, 14),
    ]
    for dx, dy, radius in blobs:
        r = radius * scale
        cx = x + dx * scale
        cy = y + dy * scale
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=outline)
    for i, (dx, dy, radius) in enumerate(blobs):
        r = max(2, radius * scale - 3)
        cx = x + dx * scale
        cy = y + dy * scale
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colors[i % len(colors)])
    image.alpha_composite(layer)


def draw_rock(image: Image.Image, x: int, y: int, scale: float) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    points = [
        (x - 14 * scale, y + 5 * scale),
        (x - 7 * scale, y - 9 * scale),
        (x + 8 * scale, y - 12 * scale),
        (x + 17 * scale, y),
        (x + 10 * scale, y + 12 * scale),
        (x - 8 * scale, y + 13 * scale),
    ]
    draw.polygon(points, fill=(70, 74, 69, 150))
    inner = [(px * 0.9 + x * 0.1, py * 0.9 + y * 0.1) for px, py in points]
    draw.polygon(inner, fill=(126, 129, 116, 210))
    draw.line((x - 4 * scale, y - 7 * scale, x + 9 * scale, y - 3 * scale), fill=(168, 170, 154, 190), width=2)
    layer = layer.filter(ImageFilter.GaussianBlur(0.2))
    image.alpha_composite(layer)


def draw_flower(draw: ImageDraw.ImageDraw, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    for angle in range(0, 360, 90):
        dx = math.cos(math.radians(angle)) * 3
        dy = math.sin(math.radians(angle)) * 3
        draw.ellipse((x + dx - 2, y + dy - 2, x + dx + 2, y + dy + 2), fill=color)
    draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(246, 218, 74, 240))


def generate() -> Image.Image:
    random.seed(42)
    image = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    pixels = image.load()

    base_a = (70, 143, 70)
    base_b = (106, 177, 84)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            broad = (math.sin(x / 92.0) + math.cos(y / 77.0) + math.sin((x + y) / 131.0)) / 3.0
            fine = random.random() * 0.08
            t = max(0.0, min(1.0, 0.52 + broad * 0.18 + fine))
            color = mix(base_a, base_b, t)
            pixels[x, y] = (*color, 255)

    draw = ImageDraw.Draw(image)

    # Soft tile-sized variation without drawing actual grid lines.
    tile_overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    tile_draw = ImageDraw.Draw(tile_overlay)
    for row in range(HEIGHT // CELL):
        for col in range(WIDTH // CELL):
            jitter = random.randint(-4, 4)
            if (row + col) % 2 == 0:
                overlay = (255, 255, 220, 9 + jitter)
            else:
                overlay = (24, 64, 35, 7 + jitter)
            tile_draw.rectangle((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL), fill=overlay)
    image.alpha_composite(tile_overlay.filter(ImageFilter.GaussianBlur(10)))

    for _ in range(260):
        x = random.randint(8, WIDTH - 8)
        y = random.randint(8, HEIGHT - 8)
        color = random.choice([
            (48, 121, 59, 170),
            (118, 194, 91, 150),
            (76, 154, 70, 145),
        ])
        draw_blade(draw, x, y, color)

    for _ in range(34):
        x = random.randint(25, WIDTH - 25)
        y = random.randint(25, HEIGHT - 25)
        scale = random.uniform(0.45, 0.9)
        draw_bush(image, x, y, scale)

    for _ in range(25):
        x = random.randint(25, WIDTH - 25)
        y = random.randint(25, HEIGHT - 25)
        scale = random.uniform(0.45, 0.85)
        draw_rock(image, x, y, scale)

    draw = ImageDraw.Draw(image)
    for _ in range(55):
        x = random.randint(16, WIDTH - 16)
        y = random.randint(16, HEIGHT - 16)
        color = random.choice([
            (244, 111, 108, 225),
            (238, 214, 82, 225),
            (178, 118, 230, 225),
            (248, 246, 220, 225),
        ])
        draw_flower(draw, x, y, color)

    vignette = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    margin = 54
    vdraw.rectangle((0, 0, WIDTH, HEIGHT), fill=(10, 32, 18, 34))
    vdraw.rectangle((margin, margin, WIDTH - margin, HEIGHT - margin), fill=(0, 0, 0, 0))
    image.alpha_composite(vignette.filter(ImageFilter.GaussianBlur(22)))
    return image


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / "cartoon_grassland.png"
    generate().save(path)
    print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
