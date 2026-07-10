"""Génère les PNG de marque (splash + launcher) alignés sur AppLogo."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "images"
GREEN = (11, 110, 79)
GREEN_DARK = (8, 74, 54)
WHITE = (255, 255, 255)


def _pt(cx: float, cy: float, x: float, y: float, scale: float) -> tuple[float, float]:
    return (cx + (x - 12) * scale, cy + (y - 12) * scale)


def draw_storefront(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    size: float,
    fill: tuple[int, ...],
) -> None:
    """Silhouette inspirée de Icons.storefront_rounded (Material)."""
    s = size / 24

    def p(x: float, y: float) -> tuple[float, float]:
        return _pt(cx, cy, x, y, s)

    draw.polygon([p(4, 8), p(12, 4), p(20, 8), p(20, 10), p(4, 10)], fill=fill)
    draw.polygon([p(7, 10), p(17, 10), p(17, 22), p(7, 22)], fill=fill)
    draw.polygon([p(4, 12), p(7, 12), p(7, 20), p(4, 20)], fill=fill)
    draw.polygon([p(17, 12), p(20, 12), p(20, 20), p(17, 20)], fill=fill)
    draw.polygon([p(2, 22), p(22, 22), p(22, 24), p(2, 24)], fill=fill)


def _radial_green(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = img.load()
    center = (size - 1) / 2
    radius = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - center, y - center) / radius
            if d > 1:
                continue
            t = (x + y) / (2 * size)
            r = int(GREEN[0] * (1 - t) + GREEN_DARK[0] * t)
            g = int(GREEN[1] * (1 - t) + GREEN_DARK[1] * t)
            b = int(GREEN[2] * (1 - t) + GREEN_DARK[2] * t)
            pixels[x, y] = (r, g, b, 255)
    return img


def make_app_icon(size: int = 1024) -> Image.Image:
    img = _radial_green(size)
    draw = ImageDraw.Draw(img)
    draw_storefront(draw, size / 2, size / 2, size * 0.52, WHITE + (255,))
    return img


def make_foreground(size: int = 1024) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_storefront(draw, size / 2, size / 2, size * 0.52, WHITE + (255,))
    return img


def make_splash_logo(size: int = 512) -> Image.Image:
    """Badge verre dépoli (AppLogo.onDark) sur fond transparent."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = size * 0.06
    bbox = [margin, margin, size - margin, size - margin]

    draw.ellipse(bbox, fill=(255, 255, 255, 64))
    border = max(2, int(size * 0.018))
    draw.ellipse(bbox, outline=(255, 255, 255, 76), width=border)

    draw_storefront(draw, size / 2, size / 2, size * 0.48, WHITE + (255,))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_app_icon().save(OUT / "app_icon.png")
    make_foreground().save(OUT / "app_icon_foreground.png")
    make_splash_logo().save(OUT / "splash_logo.png")
    print(f"Assets écrits dans {OUT}")


if __name__ == "__main__":
    main()
