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


def base_texture(seed: int, dark: tuple[int, int, int], light: tuple[int, int, int]) -> Image.Image:
    random.seed(seed)
    image = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            broad = (
                math.sin((x + seed) / 88.0)
                + math.cos((y - seed) / 74.0)
                + math.sin((x * 0.7 + y * 1.2) / 132.0)
            ) / 3.0
            fine = random.random() * 0.09
            t = max(0.0, min(1.0, 0.53 + broad * 0.22 + fine))
            pixels[x, y] = (*mix(dark, light, t), 255)
    return image


def add_soft_cell_variation(image: Image.Image, light: tuple[int, int, int], dark: tuple[int, int, int]) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for row in range(HEIGHT // CELL):
        for col in range(WIDTH // CELL):
            alpha = random.randint(4, 10)
            color = (*light, alpha) if (row + col) % 2 == 0 else (*dark, alpha)
            draw.rectangle((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL), fill=color)
    image.alpha_composite(overlay.filter(ImageFilter.GaussianBlur(12)))


def add_vignette(image: Image.Image, color: tuple[int, int, int], alpha: int) -> None:
    vignette = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(vignette)
    margin = 50
    draw.rectangle((0, 0, WIDTH, HEIGHT), fill=(*color, alpha))
    draw.rectangle((margin, margin, WIDTH - margin, HEIGHT - margin), fill=(0, 0, 0, 0))
    image.alpha_composite(vignette.filter(ImageFilter.GaussianBlur(24)))


def draw_crack(draw: ImageDraw.ImageDraw, x: int, y: int, length: int, color: tuple[int, int, int, int]) -> None:
    points = [(x, y)]
    angle = random.uniform(-0.8, 0.8)
    for _ in range(random.randint(3, 5)):
        last = points[-1]
        angle += random.uniform(-0.55, 0.55)
        step = length / 4.0 * random.uniform(0.7, 1.2)
        points.append((last[0] + math.cos(angle) * step, last[1] + math.sin(angle) * step))
    draw.line(points, fill=color, width=random.choice([2, 2, 3]), joint="curve")


def draw_stone(image: Image.Image, x: int, y: int, scale: float, fill: tuple[int, int, int, int]) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    points = []
    for i in range(7):
        angle = math.tau * i / 7.0 + random.uniform(-0.18, 0.18)
        radius = random.uniform(10, 18) * scale
        points.append((x + math.cos(angle) * radius, y + math.sin(angle) * radius))
    draw.polygon(points, fill=(35, 35, 35, 90))
    inner = [(px * 0.9 + x * 0.1, py * 0.9 + y * 0.1) for px, py in points]
    draw.polygon(inner, fill=fill)
    draw.line((x - 6 * scale, y - 5 * scale, x + 8 * scale, y - 2 * scale), fill=(255, 255, 230, 70), width=2)
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.2)))


def draw_cactus(image: Image.Image, x: int, y: int, scale: float) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    outline = (52, 83, 61, 210)
    fill = (83, 138, 83, 225)
    trunk = (x - 5 * scale, y - 24 * scale, x + 7 * scale, y + 16 * scale)
    draw.rounded_rectangle(trunk, radius=int(6 * scale), fill=outline)
    draw.rounded_rectangle((trunk[0] + 3, trunk[1] + 3, trunk[2] - 3, trunk[3] - 3), radius=int(4 * scale), fill=fill)
    for side in [-1, 1]:
        arm = (
            x + side * 4 * scale,
            y - 10 * scale,
            x + side * 20 * scale,
            y + 4 * scale,
        )
        draw.line((arm[0], arm[1], arm[2], arm[1], arm[2], arm[3]), fill=outline, width=max(3, int(8 * scale)))
        draw.line((arm[0], arm[1], arm[2], arm[1], arm[2], arm[3]), fill=fill, width=max(2, int(5 * scale)))
    image.alpha_composite(layer)


def generate_canyon() -> Image.Image:
    image = base_texture(120, (111, 77, 52), (184, 132, 79))
    add_soft_cell_variation(image, (236, 190, 118), (79, 57, 45))
    draw = ImageDraw.Draw(image)

    for _ in range(46):
        x = random.randint(8, WIDTH - 8)
        y = random.randint(8, HEIGHT - 8)
        draw_crack(draw, x, y, random.randint(22, 58), (82, 54, 42, 110))

    for _ in range(38):
        draw_stone(
            image,
            random.randint(18, WIDTH - 18),
            random.randint(18, HEIGHT - 18),
            random.uniform(0.55, 1.05),
            random.choice([(134, 111, 91, 215), (96, 92, 86, 205), (156, 120, 82, 210)]),
        )

    for _ in range(16):
        draw_cactus(image, random.randint(28, WIDTH - 28), random.randint(38, HEIGHT - 26), random.uniform(0.55, 0.9))

    for _ in range(75):
        x = random.randint(0, WIDTH)
        y = random.randint(0, HEIGHT)
        draw.line((x, y, x + random.randint(-4, 6), y - random.randint(4, 10)), fill=(78, 105, 66, 95), width=2)

    add_vignette(image, (52, 34, 27), 28)
    return image


def draw_lava_pool(image: Image.Image, x: int, y: int, rx: int, ry: int) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((x - rx - 5, y - ry - 5, x + rx + 5, y + ry + 5), fill=(54, 25, 21, 180))
    draw.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(193, 56, 28, 220))
    draw.ellipse((x - rx * 0.65, y - ry * 0.55, x + rx * 0.65, y + ry * 0.55), fill=(255, 138, 45, 210))
    draw.ellipse((x - rx * 0.28, y - ry * 0.25, x + rx * 0.28, y + ry * 0.25), fill=(255, 218, 86, 190))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))


def generate_lava() -> Image.Image:
    image = base_texture(240, (58, 45, 42), (111, 66, 43))
    add_soft_cell_variation(image, (199, 93, 48), (28, 21, 21))
    draw = ImageDraw.Draw(image)

    for _ in range(62):
        x = random.randint(8, WIDTH - 8)
        y = random.randint(8, HEIGHT - 8)
        draw_crack(draw, x, y, random.randint(24, 68), (25, 20, 20, 135))
        if random.random() < 0.45:
            draw_crack(draw, x, y, random.randint(14, 38), (238, 87, 33, 90))

    for _ in range(17):
        draw_lava_pool(
            image,
            random.randint(30, WIDTH - 30),
            random.randint(30, HEIGHT - 30),
            random.randint(10, 28),
            random.randint(6, 18),
        )

    for _ in range(42):
        draw_stone(
            image,
            random.randint(18, WIDTH - 18),
            random.randint(18, HEIGHT - 18),
            random.uniform(0.55, 1.1),
            random.choice([(62, 58, 56, 225), (81, 70, 62, 220), (49, 45, 44, 220)]),
        )

    for _ in range(40):
        x = random.randint(6, WIDTH - 6)
        y = random.randint(6, HEIGHT - 6)
        draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=random.choice([(255, 132, 42, 150), (255, 202, 74, 130)]))

    add_vignette(image, (24, 13, 12), 42)
    return image


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "cartoon_canyon.png": generate_canyon(),
        "cartoon_lava.png": generate_lava(),
    }
    for name, image in outputs.items():
        path = OUT_DIR / name
        image.save(path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
