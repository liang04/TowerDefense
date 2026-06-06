from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ENEMY_DIR = ROOT / "assets" / "sprites" / "enemies"
TOWER_DIR = ROOT / "assets" / "sprites" / "towers"
SIZE = 128


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def ellipse_shadow(image: Image.Image, box: tuple[int, int, int, int], alpha: int = 55) -> None:
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.ellipse(box, fill=(18, 20, 24, alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    image.alpha_composite(shadow)


def outlined_ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=(36, 38, 42, 255), width=5):
    draw.ellipse(box, fill=outline)
    inset = width
    draw.ellipse(
        (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset),
        fill=fill,
    )


def outlined_rect(draw: ImageDraw.ImageDraw, box, fill, outline=(36, 38, 42, 255), width=5, radius=12):
    draw.rounded_rectangle(box, radius=radius, fill=outline)
    inset = width
    draw.rounded_rectangle(
        (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset),
        radius=max(1, radius - inset),
        fill=fill,
    )


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def grunt() -> Image.Image:
    image, draw = canvas()
    ellipse_shadow(image, (31, 76, 97, 108))
    outlined_ellipse(draw, (34, 34, 94, 94), (76, 188, 93, 255))
    outlined_ellipse(draw, (24, 58, 45, 82), (57, 154, 71, 255), width=4)
    outlined_ellipse(draw, (83, 58, 104, 82), (57, 154, 71, 255), width=4)
    outlined_ellipse(draw, (44, 48, 57, 61), (250, 250, 238, 255), width=3)
    outlined_ellipse(draw, (71, 48, 84, 61), (250, 250, 238, 255), width=3)
    draw.ellipse((49, 52, 54, 57), fill=(28, 31, 35, 255))
    draw.ellipse((76, 52, 81, 57), fill=(28, 31, 35, 255))
    draw.arc((50, 60, 78, 79), start=15, end=165, fill=(34, 38, 40, 255), width=4)
    draw.ellipse((45, 37, 83, 48), fill=(117, 224, 118, 90))
    return image


def runner() -> Image.Image:
    image, draw = canvas()
    ellipse_shadow(image, (28, 79, 101, 107), 50)
    points = [(64, 22), (99, 60), (76, 101), (29, 80), (36, 43)]
    draw.polygon(points, fill=(35, 38, 42, 255))
    inner = [(64, 30), (90, 60), (73, 91), (39, 76), (44, 48)]
    draw.polygon(inner, fill=(244, 200, 56, 255))
    draw.polygon([(72, 34), (90, 44), (83, 55)], fill=(255, 236, 117, 255))
    draw.polygon([(38, 79), (19, 96), (44, 92)], fill=(35, 38, 42, 255))
    draw.polygon([(42, 77), (28, 91), (49, 87)], fill=(234, 122, 48, 255))
    draw.ellipse((54, 52, 65, 63), fill=(250, 250, 238, 255), outline=(35, 38, 42, 255), width=3)
    draw.ellipse((70, 59, 81, 70), fill=(250, 250, 238, 255), outline=(35, 38, 42, 255), width=3)
    draw.ellipse((58, 56, 62, 60), fill=(28, 31, 35, 255))
    draw.ellipse((74, 63, 78, 67), fill=(28, 31, 35, 255))
    return image


def tank() -> Image.Image:
    image, draw = canvas()
    ellipse_shadow(image, (23, 78, 106, 111), 62)
    outlined_rect(draw, (28, 32, 100, 95), (137, 122, 103, 255), width=6, radius=18)
    outlined_ellipse(draw, (39, 41, 89, 88), (166, 151, 125, 255), width=5)
    draw.rounded_rectangle((20, 53, 42, 76), radius=8, fill=(35, 38, 42, 255))
    draw.rounded_rectangle((86, 53, 108, 76), radius=8, fill=(35, 38, 42, 255))
    draw.rounded_rectangle((25, 58, 40, 72), radius=5, fill=(108, 96, 82, 255))
    draw.rounded_rectangle((88, 58, 103, 72), radius=5, fill=(108, 96, 82, 255))
    draw.rectangle((49, 52, 58, 62), fill=(250, 250, 238, 255))
    draw.rectangle((70, 52, 79, 62), fill=(250, 250, 238, 255))
    draw.rectangle((52, 56, 56, 61), fill=(28, 31, 35, 255))
    draw.rectangle((73, 56, 77, 61), fill=(28, 31, 35, 255))
    draw.arc((50, 62, 78, 82), start=20, end=160, fill=(54, 45, 39, 255), width=4)
    return image


def arrow_tower() -> Image.Image:
    image, draw = canvas()
    ellipse_shadow(image, (26, 82, 102, 112), 58)
    outlined_rect(draw, (36, 48, 92, 94), (89, 124, 185, 255), width=6, radius=13)
    outlined_ellipse(draw, (31, 27, 97, 73), (130, 169, 231, 255), width=6)
    draw.rectangle((60, 16, 68, 58), fill=(37, 42, 48, 255))
    draw.polygon([(64, 9), (49, 31), (79, 31)], fill=(37, 42, 48, 255))
    draw.polygon([(64, 15), (55, 29), (73, 29)], fill=(236, 216, 89, 255))
    draw.rounded_rectangle((51, 61, 77, 76), radius=6, fill=(37, 42, 48, 255))
    draw.rounded_rectangle((55, 63, 73, 72), radius=4, fill=(230, 198, 92, 255))
    return image


def cannon_tower() -> Image.Image:
    image, draw = canvas()
    ellipse_shadow(image, (24, 82, 104, 113), 60)
    outlined_rect(draw, (34, 56, 94, 96), (185, 87, 52, 255), width=6, radius=14)
    draw.rounded_rectangle((55, 25, 91, 48), radius=11, fill=(35, 38, 42, 255))
    draw.rounded_rectangle((60, 30, 92, 43), radius=7, fill=(91, 94, 99, 255))
    outlined_ellipse(draw, (36, 35, 86, 82), (219, 122, 64, 255), width=6)
    draw.ellipse((51, 47, 71, 67), fill=(92, 54, 44, 255))
    draw.arc((42, 41, 80, 73), start=205, end=315, fill=(255, 190, 92, 255), width=5)
    return image


def frost_tower() -> Image.Image:
    image, draw = canvas()
    ellipse_shadow(image, (24, 82, 104, 112), 54)
    outlined_rect(draw, (35, 55, 93, 96), (78, 181, 214, 255), width=6, radius=14)
    outlined_ellipse(draw, (35, 31, 93, 79), (151, 230, 242, 255), width=6)
    draw.polygon([(64, 17), (78, 43), (64, 69), (50, 43)], fill=(35, 38, 42, 255))
    draw.polygon([(64, 24), (72, 43), (64, 62), (56, 43)], fill=(220, 252, 255, 255))
    draw.line((39, 48, 89, 48), fill=(225, 252, 255, 255), width=5)
    draw.line((45, 36, 83, 60), fill=(225, 252, 255, 255), width=4)
    draw.line((45, 60, 83, 36), fill=(225, 252, 255, 255), width=4)
    return image


def main() -> None:
    assets = {
        ENEMY_DIR / "grunt_0.png": grunt(),
        ENEMY_DIR / "runner_0.png": runner(),
        ENEMY_DIR / "tank_0.png": tank(),
        TOWER_DIR / "arrow_0.png": arrow_tower(),
        TOWER_DIR / "cannon_0.png": cannon_tower(),
        TOWER_DIR / "frost_0.png": frost_tower(),
    }
    for path, image in assets.items():
        save(image, path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
