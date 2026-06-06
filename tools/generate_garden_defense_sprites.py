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


def peashooter(frame: int = 0) -> Image.Image:
    sway = [0, -2, 0, 2][frame % 4]
    bob = [0, -1, 0, 1][frame % 4]
    image, draw = canvas()
    shadow(image, (26, 82, 102, 112))
    draw.rounded_rectangle((57 + sway, 62 + bob, 70 + sway, 98), radius=6, fill=(37, 112, 50, 255))
    leaf(draw, [(60 + sway, 78), (33 + sway // 2, 65), (43 + sway // 2, 91)], (71, 172, 78, 255))
    leaf(draw, [(68 + sway, 80), (96 + sway // 2, 67), (86 + sway // 2, 94)], (88, 186, 83, 255))
    ellipse(draw, (32 + sway, 28 + bob, 86 + sway, 78 + bob), (94, 190, 85, 255), width=5)
    rounded(draw, (73 + sway, 39 + bob, 112 + sway, 63 + bob), (84, 178, 78, 255), radius=13, width=5)
    draw.ellipse((97 + sway, 45 + bob, 108 + sway, 57 + bob), fill=(35, 70, 37, 255))
    eyes(draw, (51 + sway, 51 + bob), (67 + sway, 51 + bob))
    draw.arc((51 + sway, 56 + bob, 72 + sway, 72 + bob), 20, 160, fill=(31, 73, 38, 255), width=3)
    return image


def blastfruit(frame: int = 0) -> Image.Image:
    sway = [0, 2, 0, -2][frame % 4]
    squash = [0, -1, 0, 1][frame % 4]
    image, draw = canvas()
    shadow(image, (25, 83, 104, 114), 60)
    draw.rounded_rectangle((59 + sway, 67 + squash, 70 + sway, 96), radius=5, fill=(86, 112, 45, 255))
    leaf(draw, [(64 + sway, 65), (36 + sway // 2, 55), (44 + sway // 2, 82)], (87, 151, 60, 255))
    leaf(draw, [(67 + sway, 67), (94 + sway // 2, 55), (87 + sway // 2, 83)], (95, 162, 63, 255))
    ellipse(draw, (32 + sway, 33 + squash, 96 + sway, 94 - squash), (225, 104, 49, 255), width=6)
    draw.ellipse((43 + sway, 42 + squash, 80 + sway, 72 + squash), fill=(255, 157, 64, 210))
    draw.polygon([(64 + sway, 25 + squash), (74 + sway, 14 + squash), (82 + sway, 30 + squash), (72 + sway, 37 + squash)], fill=OUTLINE)
    draw.polygon([(66 + sway, 27 + squash), (73 + sway, 19 + squash), (78 + sway, 30 + squash), (71 + sway, 34 + squash)], fill=(245, 214, 75, 255))
    eyes(draw, (53 + sway, 61 + squash), (74 + sway, 61 + squash))
    draw.arc((54 + sway, 69 + squash, 78 + sway, 84 + squash), 20, 160, fill=(92, 42, 28, 255), width=4)
    return image


def frostflower(frame: int = 0) -> Image.Image:
    sway = [0, -2, 0, 2][frame % 4]
    bob = [0, 1, 0, -1][frame % 4]
    image, draw = canvas()
    shadow(image, (25, 83, 103, 113), 50)
    draw.rounded_rectangle((58 + sway, 66 + bob, 70 + sway, 98), radius=6, fill=(37, 127, 120, 255))
    leaf(draw, [(62 + sway, 80), (35 + sway // 2, 68), (45 + sway // 2, 94)], (78, 184, 154, 255))
    leaf(draw, [(69 + sway, 79), (96 + sway // 2, 67), (88 + sway // 2, 94)], (80, 197, 179, 255))
    center = (64 + sway, 51 + bob)
    petals = [
        (64 + sway, 18 + bob, 80 + sway, 50 + bob, 64 + sway, 84 + bob, 48 + sway, 50 + bob),
        (31 + sway, 51 + bob, 64 + sway, 35 + bob, 97 + sway, 51 + bob, 64 + sway, 67 + bob),
        (43 + sway, 28 + bob, 70 + sway, 44 + bob, 85 + sway, 73 + bob, 58 + sway, 58 + bob),
        (85 + sway, 28 + bob, 70 + sway, 58 + bob, 43 + sway, 73 + bob, 58 + sway, 44 + bob),
    ]
    for p in petals:
        draw.polygon([(p[0], p[1]), (p[2], p[3]), (p[4], p[5]), (p[6], p[7])], fill=OUTLINE)
        inner = [(x * 0.86 + center[0] * 0.14, y * 0.86 + center[1] * 0.14) for x, y in [(p[0], p[1]), (p[2], p[3]), (p[4], p[5]), (p[6], p[7])]]
        draw.polygon(inner, fill=(177, 239, 245, 255))
    ellipse(draw, (45 + sway, 33 + bob, 83 + sway, 71 + bob), (98, 208, 224, 255), width=5)
    eyes(draw, (55 + sway, 51 + bob), (73 + sway, 51 + bob))
    return image


def basic_zombie(frame: int = 0) -> Image.Image:
    bob = [0, -2, 0, 2][frame % 4]
    swing = [-7, 0, 7, 0][frame % 4]
    image, draw = canvas()
    shadow(image, (30, 83, 99, 114), 58)
    draw.line((52, 91 + bob, 43 + swing, 110), fill=OUTLINE, width=7)
    draw.line((76, 91 + bob, 85 - swing, 110), fill=OUTLINE, width=7)
    rounded(draw, (38, 43 + bob, 90, 98 + bob), (103, 167, 112, 255), radius=17, width=5)
    ellipse(draw, (34, 20 + bob, 94, 74 + bob), (126, 187, 132, 255), width=5)
    draw.rectangle((49, 75 + bob, 78, 95 + bob), fill=(91, 91, 115, 255))
    draw.line((42, 46 + bob, 27 + swing, 59 + bob), fill=OUTLINE, width=6)
    draw.line((86, 46 + bob, 101 - swing, 57 + bob), fill=OUTLINE, width=6)
    draw.line((42, 38 + bob, 28, 28 + bob), fill=OUTLINE, width=5)
    draw.line((86, 38 + bob, 100, 28 + bob), fill=OUTLINE, width=5)
    eyes(draw, (52, 45 + bob), (75, 47 + bob))
    draw.rectangle((55, 60 + bob, 73, 65 + bob), fill=(55, 63, 57, 255))
    draw.line((56, 64 + bob, 56, 69 + bob), fill=(234, 235, 215, 255), width=2)
    draw.line((68, 64 + bob, 68, 69 + bob), fill=(234, 235, 215, 255), width=2)
    return image


def runner_zombie(frame: int = 0) -> Image.Image:
    bob = [0, -4, 0, 3][frame % 4]
    lean = [2, 5, 2, -1][frame % 4]
    swing = [-12, 8, 12, -8][frame % 4]
    image, draw = canvas()
    shadow(image, (24, 84, 106, 114), 55)
    draw.line((50 + lean, 90 + bob, 35 + swing, 112), fill=OUTLINE, width=7)
    draw.line((80 + lean, 91 + bob, 98 - swing, 111), fill=OUTLINE, width=7)
    rounded(draw, (41 + lean, 45 + bob, 91 + lean, 97 + bob), (119, 176, 116, 255), radius=16, width=5)
    ellipse(draw, (37 + lean, 22 + bob, 93 + lean, 72 + bob), (139, 199, 132, 255), width=5)
    draw.polygon([(43 + lean, 28 + bob), (87 + lean, 26 + bob), (97 + lean, 43 + bob), (32 + lean, 43 + bob)], fill=OUTLINE)
    draw.polygon([(47 + lean, 31 + bob), (85 + lean, 30 + bob), (90 + lean, 39 + bob), (39 + lean, 39 + bob)], fill=(246, 207, 63, 255))
    draw.line((43 + lean, 79 + bob, 20 + swing, 96 + bob), fill=OUTLINE, width=6)
    draw.line((82 + lean, 82 + bob, 111 - swing, 96 + bob), fill=OUTLINE, width=6)
    eyes(draw, (54 + lean, 48 + bob), (76 + lean, 49 + bob))
    draw.arc((53 + lean, 59 + bob, 77 + lean, 76 + bob), 20, 160, fill=(55, 63, 57, 255), width=4)
    return image


def bucket_zombie(frame: int = 0) -> Image.Image:
    bob = [0, -1, 0, 1][frame % 4]
    swing = [-5, 0, 5, 0][frame % 4]
    image, draw = canvas()
    shadow(image, (24, 84, 106, 116), 66)
    draw.line((52, 95 + bob, 44 + swing, 113), fill=OUTLINE, width=8)
    draw.line((78, 95 + bob, 86 - swing, 113), fill=OUTLINE, width=8)
    rounded(draw, (36, 46 + bob, 93, 101 + bob), (113, 158, 111, 255), radius=15, width=5)
    ellipse(draw, (35, 27 + bob, 95, 80 + bob), (129, 183, 127, 255), width=5)
    draw.line((42, 63 + bob, 25 + swing, 76 + bob), fill=OUTLINE, width=7)
    draw.line((89, 63 + bob, 106 - swing, 76 + bob), fill=OUTLINE, width=7)
    draw.polygon([(38, 21 + bob), (90, 21 + bob), (99, 53 + bob), (29, 53 + bob)], fill=OUTLINE)
    draw.polygon([(43, 26 + bob), (86, 26 + bob), (92, 48 + bob), (36, 48 + bob)], fill=(133, 137, 133, 255))
    draw.line((41, 33 + bob, 89, 33 + bob), fill=(186, 189, 179, 210), width=3)
    eyes(draw, (53, 58 + bob), (76, 58 + bob))
    draw.rectangle((54, 72 + bob, 76, 78 + bob), fill=(58, 65, 58, 255))
    draw.rectangle((59, 78 + bob, 64, 85 + bob), fill=(238, 236, 214, 255))
    draw.rectangle((69, 78 + bob, 74, 85 + bob), fill=(238, 236, 214, 255))
    return image


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main() -> None:
    assets = {
    }
    for i in range(4):
        assets[TOWER_DIR / f"arrow_{i}.png"] = peashooter(i)
        assets[TOWER_DIR / f"cannon_{i}.png"] = blastfruit(i)
        assets[TOWER_DIR / f"frost_{i}.png"] = frostflower(i)
    for i in range(4):
        assets[ENEMY_DIR / f"grunt_{i}.png"] = basic_zombie(i)
        assets[ENEMY_DIR / f"runner_{i}.png"] = runner_zombie(i)
        assets[ENEMY_DIR / f"tank_{i}.png"] = bucket_zombie(i)
    for path, image in assets.items():
        save(image, path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
