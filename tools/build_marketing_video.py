"""Assemble une vidéo publicitaire ARIKE à partir des affiches marketing."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
POSTERS_DIR = ROOT / "assets" / "marketing"
OUT_DIR = ROOT / "assets" / "marketing"
OUT_MP4 = OUT_DIR / "arike-pub-marketing.mp4"
OUT_GIF = OUT_DIR / "arike-pub-marketing.gif"
OUT_WEBP = OUT_DIR / "arike-pub-marketing.webp"
# Alias compat (anciens noms)
OUT_MP4_LEGACY = OUT_DIR / "venteapp-pub-marketing.mp4"
OUT_GIF_LEGACY = OUT_DIR / "venteapp-pub-marketing.gif"
OUT_WEBP_LEGACY = OUT_DIR / "venteapp-pub-marketing.webp"

# Ordre narratif de la publicité
SEQUENCE = [
    ("affiche-arike-marque.png", "La gestion commerciale du Bénin"),
    ("affiche-module-tableau-bord.png", "Pilotez votre journée"),
    ("affiche-module-ventes.png", "Vendez en quelques secondes"),
    ("affiche-module-inventaire.png", "Stock sous contrôle"),
    ("affiche-module-clients-credit.png", "Clients & crédit maîtrisés"),
    ("affiche-module-caisse.png", "Caisse claire, chaque jour"),
    ("affiche-module-depenses.png", "Dépenses suivies"),
    ("affiche-module-statistiques.png", "Pilotage en un regard"),
    ("affiche-module-calculateurs.png", "Calculateurs métiers"),
    ("affiche-module-hors-ligne.png", "Même sans Internet"),
    ("affiche-module-equipe-securite.png", "Équipe & sécurité"),
    ("affiche-module-multi-boutiques.png", "Multi-boutiques"),
    ("affiche-arike-marque.png", "ARIKE — démarrez aujourd'hui"),
]

W, H = 540, 720  # 3:4 compact pour partage mobile
FPS = 12
HOLD_SECONDS = 1.8
FADE_SECONDS = 0.35
GREEN = (11, 110, 79, 255)
GOLD = (232, 163, 23, 255)
WHITE = (255, 255, 255, 255)


def _font(size: int) -> ImageFont.ImageFont:
    for name in (
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ):
        path = Path(name)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def _fit(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    src_w, src_h = img.size
    scale = max(W / src_w, H / src_h)
    nw, nh = int(src_w * scale), int(src_h * scale)
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - W) // 2
    top = (nh - H) // 2
    return resized.crop((left, top, left + W, top + H))


def _caption_bar(text: str) -> Image.Image:
    bar = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bar)
    # Soft bottom gradient strip
    for y in range(H - 180, H):
        alpha = int(170 * ((y - (H - 180)) / 180))
        draw.line([(0, y), (W, y)], fill=(8, 74, 54, alpha))
    draw.rounded_rectangle(
        (28, H - 128, W - 28, H - 36),
        radius=16,
        fill=(11, 110, 79, 220),
        outline=GOLD,
        width=2,
    )
    font = _font(28)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(
        ((W - tw) / 2, H - 128 + (92 - th) / 2),
        text,
        font=font,
        fill=WHITE,
    )
    return bar


def _blend(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    t = max(0.0, min(1.0, t))
    return Image.blend(a.convert("RGBA"), b.convert("RGBA"), t)


def build_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    hold = int(HOLD_SECONDS * FPS)
    fade = max(1, int(FADE_SECONDS * FPS))

    prepared: list[Image.Image] = []
    for filename, caption in SEQUENCE:
        path = POSTERS_DIR / filename
        if not path.exists():
            raise FileNotFoundError(path)
        base = _fit(Image.open(path))
        composed = Image.alpha_composite(base, _caption_bar(caption))
        prepared.append(composed.convert("RGB"))

    for i, frame in enumerate(prepared):
        for _ in range(hold):
            frames.append(frame)
        if i < len(prepared) - 1:
            nxt = prepared[i + 1]
            for step in range(1, fade + 1):
                frames.append(_blend(frame.convert("RGBA"), nxt.convert("RGBA"), step / fade).convert("RGB"))
    return frames


def write_gif(frames: list[Image.Image]) -> None:
    step = max(1, FPS // 6)
    gif_frames = [f.convert("P", palette=Image.Palette.ADAPTIVE, colors=64) for f in frames[::step]]
    gif_frames[0].save(
        OUT_GIF,
        save_all=True,
        append_images=gif_frames[1:],
        duration=int(1000 / 6),
        loop=0,
        optimize=True,
    )
    print(f"GIF: {OUT_GIF} ({OUT_GIF.stat().st_size // 1024} Ko)")
    # Alias legacy
    gif_frames[0].save(
        OUT_GIF_LEGACY,
        save_all=True,
        append_images=gif_frames[1:],
        duration=int(1000 / 6),
        loop=0,
        optimize=True,
    )


def write_webp(frames: list[Image.Image]) -> None:
    step = max(1, FPS // 8)
    webp_frames = frames[::step]
    webp_frames[0].save(
        OUT_WEBP,
        save_all=True,
        append_images=webp_frames[1:],
        duration=int(1000 / 8),
        loop=0,
        quality=70,
    )
    print(f"WEBP: {OUT_WEBP}")
    webp_frames[0].save(
        OUT_WEBP_LEGACY,
        save_all=True,
        append_images=webp_frames[1:],
        duration=int(1000 / 8),
        loop=0,
        quality=70,
    )


def write_mp4(frames: list[Image.Image]) -> None:
    import imageio.v2 as imageio
    import numpy as np
    import shutil

    writer = imageio.get_writer(
        OUT_MP4,
        fps=FPS,
        codec="libx264",
        quality=8,
        pixelformat="yuv420p",
        macro_block_size=None,
    )
    try:
        for frame in frames:
            writer.append_data(np.asarray(frame))
    finally:
        writer.close()
    print(f"MP4: {OUT_MP4}")
    shutil.copyfile(OUT_MP4, OUT_MP4_LEGACY)


def main() -> None:
    print("Assemblage des plans…")
    frames = build_frames()
    print(f"{len(frames)} frames ({len(frames) / FPS:.1f}s)")
    write_gif(frames)
    try:
        write_webp(frames)
    except Exception as exc:  # noqa: BLE001
        print(f"WEBP indisponible ({exc})")
    try:
        write_mp4(frames)
    except Exception as exc:  # noqa: BLE001
        print(f"MP4 indisponible ({exc}) — GIF généré.")


if __name__ == "__main__":
    main()
