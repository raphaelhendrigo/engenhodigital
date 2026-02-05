from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMAGES_DIR = ROOT / "assets" / "images"
STORE_DIR = ROOT / "assets" / "store"
SCREEN_DIR = STORE_DIR / "screenshots"

BRAND = {
    "name": "Engenho Digital",
    "tagline": "Projetos & Sistemas",
    "accent": (250, 148, 46),
    "bg": (12, 20, 30),
    "surface": (20, 31, 45),
    "text": (245, 247, 250),
    "muted": (190, 200, 210),
}


FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/Library/Fonts/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttf",
    "/Library/Fonts/Helvetica.ttf",
    "/System/Library/Fonts/Supplemental/Verdana.ttf",
    "/Library/Fonts/Verdana.ttf",
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def center_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, box: tuple[int, int, int, int], fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x0, y0, x1, y1 = box
    x = x0 + (x1 - x0 - text_w) / 2
    y = y0 + (y1 - y0 - text_h) / 2
    draw.text((x, y), text, font=font, fill=fill)


def add_gradient(img: Image.Image, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> None:
    width, height = img.size
    for y in range(height):
        ratio = y / max(height - 1, 1)
        r = int(top[0] + (bottom[0] - top[0]) * ratio)
        g = int(top[1] + (bottom[1] - top[1]) * ratio)
        b = int(top[2] + (bottom[2] - top[2]) * ratio)
        for x in range(width):
            img.putpixel((x, y), (r, g, b))


def make_icon(path: Path, size: int = 512) -> None:
    img = Image.new("RGB", (size, size), BRAND["bg"])
    draw = ImageDraw.Draw(img)

    # Accent circle
    circle_margin = int(size * 0.12)
    draw.ellipse(
        (circle_margin, circle_margin, size - circle_margin, size - circle_margin),
        fill=BRAND["accent"],
    )

    font = load_font(int(size * 0.36))
    center_text(draw, "ED", font, (0, 0, size, size), BRAND["bg"])

    img.save(path)


def make_logo(path: Path, size: int = 512) -> None:
    img = Image.new("RGB", (size, size), BRAND["bg"])
    draw = ImageDraw.Draw(img)

    font_title = load_font(int(size * 0.12))
    font_tagline = load_font(int(size * 0.06))

    center_text(draw, BRAND["name"], font_title, (0, size * 0.35, size, size * 0.55), BRAND["text"])
    center_text(draw, BRAND["tagline"], font_tagline, (0, size * 0.52, size, size * 0.68), BRAND["muted"])

    img.save(path)


def make_presplash(path: Path, width: int = 1080, height: int = 1920) -> None:
    img = Image.new("RGB", (width, height), BRAND["bg"])
    add_gradient(img, BRAND["bg"], BRAND["surface"])
    draw = ImageDraw.Draw(img)

    font_title = load_font(int(height * 0.06))
    font_tagline = load_font(int(height * 0.03))

    center_text(draw, BRAND["name"], font_title, (0, height * 0.40, width, height * 0.55), BRAND["text"])
    center_text(draw, BRAND["tagline"], font_tagline, (0, height * 0.52, width, height * 0.62), BRAND["muted"])

    img.save(path)


def make_feature_graphic(path: Path, width: int = 1024, height: int = 500) -> None:
    img = Image.new("RGB", (width, height), BRAND["bg"])
    add_gradient(img, BRAND["bg"], BRAND["surface"])
    draw = ImageDraw.Draw(img)

    font_title = load_font(int(height * 0.24))
    font_tagline = load_font(int(height * 0.12))

    center_text(draw, BRAND["name"], font_title, (0, height * 0.18, width, height * 0.60), BRAND["text"])
    center_text(draw, BRAND["tagline"], font_tagline, (0, height * 0.55, width, height * 0.85), BRAND["muted"])

    # Accent stripe
    stripe_h = int(height * 0.04)
    draw.rectangle((0, height - stripe_h, width, height), fill=BRAND["accent"])

    img.save(path)


def make_screenshot(path: Path, title: str, subtitle: str, width: int = 1080, height: int = 1920) -> None:
    img = Image.new("RGB", (width, height), BRAND["bg"])
    add_gradient(img, BRAND["bg"], BRAND["surface"])
    draw = ImageDraw.Draw(img)

    font_title = load_font(int(height * 0.05))
    font_sub = load_font(int(height * 0.025))

    center_text(draw, title, font_title, (0, height * 0.25, width, height * 0.45), BRAND["text"])
    center_text(draw, subtitle, font_sub, (width * 0.08, height * 0.45, width * 0.92, height * 0.60), BRAND["muted"])

    # Accent block
    draw.rounded_rectangle(
        (width * 0.1, height * 0.65, width * 0.9, height * 0.78),
        radius=int(height * 0.02),
        fill=BRAND["accent"],
    )
    cta_font = load_font(int(height * 0.03))
    center_text(draw, "Entre em contato", cta_font, (width * 0.1, height * 0.65, width * 0.9, height * 0.78), BRAND["bg"])

    img.save(path)


def main() -> None:
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    STORE_DIR.mkdir(parents=True, exist_ok=True)
    SCREEN_DIR.mkdir(parents=True, exist_ok=True)

    make_icon(IMAGES_DIR / "icon.png")
    make_logo(IMAGES_DIR / "logo.png")
    make_presplash(IMAGES_DIR / "presplash.png")

    make_icon(STORE_DIR / "icon_512.png")
    make_feature_graphic(STORE_DIR / "feature_graphic_1024x500.png")

    make_screenshot(
        SCREEN_DIR / "screenshot_1.png",
        "Software sob medida",
        "Sistemas, dashboards e integrações para acelerar decisões.",
    )
    make_screenshot(
        SCREEN_DIR / "screenshot_2.png",
        "Projetos elétricos CAD/CAM",
        "Plantas, diagramas e documentação técnica completa.",
    )
    make_screenshot(
        SCREEN_DIR / "screenshot_3.png",
        "Automação e dados",
        "Processos automatizados e indicadores em tempo real.",
    )


if __name__ == "__main__":
    main()
