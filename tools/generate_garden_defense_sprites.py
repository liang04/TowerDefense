from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ENEMY_DIR = ROOT / "assets" / "sprites" / "enemies"
TOWER_DIR = ROOT / "assets" / "sprites" / "towers"
SIZE = 128
OUTLINE = (34, 38, 42, 255)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def shadow(image: Image.Image, box: tuple[int, int, int, int], alpha: int = 55) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box, fill=(18, 20, 24, alpha))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(6)))


def ellipse(draw: ImageDraw.ImageDraw, box, fill, width=5) -> None:
    draw.ellipse(box, fill=OUTLINE)
    draw.ellipse((box[0] + width, box[1] + width, box[2] - width, box[3] - width), fill=fill)


def rounded(draw: ImageDraw.ImageDraw, box, fill, radius=12, width=5) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=OUTLINE)
    draw.rounded_rectangle(
        (box[0] + width, box[1] + width, box[2] - width, box[3] - width),
        radius=max(1, radius - width),
        fill=fill,
    )


def leaf(draw: ImageDraw.ImageDraw, points, fill) -> None:
    draw.polygon(points, fill=OUTLINE)
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    inner = [(x * 0.84 + cx * 0.16, y * 0.84 + cy * 0.16) for x, y in points]
    draw.polygon(inner, fill=fill)


def eyes(draw: ImageDraw.ImageDraw, left: tuple[int, int], right: tuple[int, int]) -> None:
    for x, y in [left, right]:
        ellipse(draw, (x - 8, y - 8, x + 8, y + 8), (248, 248, 232, 255), width=3)
        draw.ellipse((x - 2, y - 1, x + 4, y + 5), fill=(24, 28, 32, 255))


def peashooter() -> Image.Image:
    image, draw = canvas()
    shadow(image, (26, 82, 102, 112))
    draw.rounded_rectangle((57, 62, 70, 98), radius=6, fill=(37, 112, 50, 255))
    leaf(draw, [(60, 78), (33, 65), (43, 91)], (71, 172, 78, 255))
    leaf(draw, [(68, 80), (96, 67), (86, 94)], (88, 186, 83, 255))
    ellipse(draw, (32, 28, 86, 78), (94, 190, 85, 255), width=5)
    rounded(draw, (73, 39, 112, 63), (84, 178, 78, 255), radius=13, width=5)
    draw.ellipse((97, 45, 108, 57), fill=(35, 70, 37, 255))
    eyes(draw, (51, 51), (67, 51))
    draw.arc((51, 56, 72, 72), 20, 160, fill=(31, 73, 38, 255), width=3)
    return image


def blastfruit() -> Image.Image:
    image, draw = canvas()
    shadow(image, (25, 83, 104, 114), 60)
    draw.rounded_rectangle((59, 67, 70, 96), radius=5, fill=(86, 112, 45, 255))
    leaf(draw, [(64, 65), (36, 55), (44, 82)], (87, 151, 60, 255))
    leaf(draw, [(67, 67), (94, 55), (87, 83)], (95, 162, 63, 255))
    ellipse(draw, (32, 33, 96, 94), (225, 104, 49, 255), width=6)
    draw.ellipse((43, 42, 80, 72), fill=(255, 157, 64, 210))
    draw.polygon([(64, 25), (74, 14), (82, 30), (72, 37)], fill=OUTLINE)
    draw.polygon([(66, 27), (73, 19), (78, 30), (71, 34)], fill=(245, 214, 75, 255))
    eyes(draw, (53, 61), (74, 61))
    draw.arc((54, 69, 78, 84), 20, 160, fill=(92, 42, 28, 255), width=4)
    return image


def frostflower() -> Image.Image:
    image, draw = canvas()
    shadow(image, (25, 83, 103, 113), 50)
    draw.rounded_rectangle((58, 66, 70, 98), radius=6, fill=(37, 127, 120, 255))
    leaf(draw, [(62, 80), (35, 68), (45, 94)], (78, 184, 154, 255))
    leaf(draw, [(69, 79), (96, 67), (88, 94)], (80, 197, 179, 255))
    center = (64, 51)
    petals = [
        (64, 18, 80, 50, 64, 84, 48, 50),
        (31, 51, 64, 35, 97, 51, 64, 67),
        (43, 28, 70, 44, 85, 73, 58, 58),
        (85, 28, 70, 58, 43, 73, 58, 44),
    ]
    for p in petals:
        draw.polygon([(p[0], p[1]), (p[2], p[3]), (p[4], p[5]), (p[6], p[7])], fill=OUTLINE)
        inner = [(x * 0.86 + center[0] * 0.14, y * 0.86 + center[1] * 0.14) for x, y in [(p[0], p[1]), (p[2], p[3]), (p[4], p[5]), (p[6], p[7])]]
        draw.polygon(inner, fill=(177, 239, 245, 255))
    ellipse(draw, (45, 33, 83, 71), (98, 208, 224, 255), width=5)
    eyes(draw, (55, 51), (73, 51))
    return image


def basic_zombie() -> Image.Image:
    image, draw = canvas()
    shadow(image, (30, 83, 99, 114), 62)
    rounded(draw, (38, 43, 90, 98), (103, 167, 112, 255), radius=17, width=5)
    ellipse(draw, (34, 20, 94, 74), (126, 187, 132, 255), width=5)
    draw.rectangle((49, 75, 78, 95), fill=(91, 91, 115, 255))
    draw.line((42, 38, 28, 28), fill=OUTLINE, width=5)
    draw.line((86, 38, 100, 28), fill=OUTLINE, width=5)
    eyes(draw, (52, 45), (75, 47))
    draw.rectangle((55, 60, 73, 65), fill=(55, 63, 57, 255))
    draw.line((56, 64, 56, 69), fill=(234, 235, 215, 255), width=2)
    draw.line((68, 64, 68, 69), fill=(234, 235, 215, 255), width=2)
    return image


def runner_zombie() -> Image.Image:
    image, draw = canvas()
    shadow(image, (24, 84, 106, 114), 55)
    rounded(draw, (41, 45, 91, 97), (119, 176, 116, 255), radius=16, width=5)
    ellipse(draw, (37, 22, 93, 72), (139, 199, 132, 255), width=5)
    draw.polygon([(43, 28), (87, 26), (97, 43), (32, 43)], fill=OUTLINE)
    draw.polygon([(47, 31), (85, 30), (90, 39), (39, 39)], fill=(246, 207, 63, 255))
    draw.line((43, 79, 24, 97), fill=OUTLINE, width=6)
    draw.line((82, 82, 105, 96), fill=OUTLINE, width=6)
    eyes(draw, (54, 48), (76, 49))
    draw.arc((53, 59, 77, 76), 20, 160, fill=(55, 63, 57, 255), width=4)
    return image


def bucket_zombie() -> Image.Image:
    image, draw = canvas()
    shadow(image, (24, 84, 106, 116), 66)
    rounded(draw, (36, 46, 93, 101), (113, 158, 111, 255), radius=15, width=5)
    ellipse(draw, (35, 27, 95, 80), (129, 183, 127, 255), width=5)
    draw.polygon([(38, 21), (90, 21), (99, 53), (29, 53)], fill=OUTLINE)
    draw.polygon([(43, 26), (86, 26), (92, 48), (36, 48)], fill=(133, 137, 133, 255))
    draw.line((41, 33, 89, 33), fill=(186, 189, 179, 210), width=3)
    eyes(draw, (53, 58), (76, 58))
    draw.rectangle((54, 72, 76, 78), fill=(58, 65, 58, 255))
    draw.rectangle((59, 78, 64, 85), fill=(238, 236, 214, 255))
    draw.rectangle((69, 78, 74, 85), fill=(238, 236, 214, 255))
    return image


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main() -> None:
    assets = {
        TOWER_DIR / "arrow_0.png": peashooter(),
        TOWER_DIR / "cannon_0.png": blastfruit(),
        TOWER_DIR / "frost_0.png": frostflower(),
        ENEMY_DIR / "grunt_0.png": basic_zombie(),
        ENEMY_DIR / "runner_0.png": runner_zombie(),
        ENEMY_DIR / "tank_0.png": bucket_zombie(),
    }
    for path, image in assets.items():
        save(image, path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
