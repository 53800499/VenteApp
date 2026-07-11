"""Affiches publicitaires ARIKE — une par module, format 3:4 partage mobile."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "marketing"
LOGO_LIGHT = ROOT / "assets" / "images" / "arike_logo_light.png"

# Palette système
GREEN = (11, 110, 79)
GREEN_MID = (14, 92, 68)
GREEN_DARK = (8, 74, 54)
GREEN_DEEP = (5, 48, 36)
GOLD = (232, 163, 23)
GOLD_SOFT = (245, 200, 90)
WHITE = (255, 255, 255)
OFF_WHITE = (244, 247, 245)
MUTED = (210, 225, 218)
CARD = (255, 255, 255)
INK = (18, 42, 34)
INK_SOFT = (70, 95, 85)

W, H = 1080, 1440

# ---------------------------------------------------------------------------
# Contenu marketing par module
# ---------------------------------------------------------------------------
POSTERS: list[dict] = [
    {
        "file": "affiche-arike-marque.png",
        "alias": "affiche-venteapp-marque.png",
        "badge": "NOUVELLE APP",
        "title": "ARIKE",
        "headline": "La gestion commerciale\ndu Bénin",
        "subtitle": "Vendez, gérez le stock et suivez vos clients —\nmême sans Internet.",
        "bullets": [
            ("Ventes & reçus", "Encaissement rapide, crédit, PDF"),
            ("Stock intelligent", "Alertes et inventaire en un geste"),
            ("100 % terrain", "Offline-first, sync automatique"),
        ],
        "cta": "Téléchargez gratuitement",
        "mock": "hero",
        "accent": GOLD,
    },
    {
        "file": "affiche-module-tableau-bord.png",
        "badge": "TABLEAU DE BORD",
        "title": "Pilotez\nvotre journée",
        "headline": "Tout l’essentiel\nen un coup d’œil",
        "subtitle": "CA du jour, ventes récentes, alertes stock\net accès direct à la caisse.",
        "bullets": [
            ("KPI du jour", "Chiffre d’affaires en direct"),
            ("Alertes", "Ruptures et dettes à suivre"),
            ("Raccourcis", "Nouvelle vente en 1 tap"),
        ],
        "cta": "Découvrir ARIKE",
        "mock": "dashboard",
        "accent": (33, 150, 243),
    },
    {
        "file": "affiche-module-ventes.png",
        "badge": "VENTES",
        "title": "Encaissez en\nquelques secondes",
        "headline": "Panier tactile,\nreçu immédiat",
        "subtitle": "Crédit client, remises, historique complet\net partage WhatsApp.",
        "bullets": [
            ("Caisse rapide", "Ajoutez, payez, c’est vendu"),
            ("Reçus PDF", "Partagez en un instant"),
            ("Crédit", "Vendez maintenant, encaissez après"),
        ],
        "cta": "Vendre avec ARIKE",
        "mock": "sales",
        "accent": (46, 125, 50),
    },
    {
        "file": "affiche-module-inventaire.png",
        "badge": "INVENTAIRE",
        "title": "Stock toujours\nsous contrôle",
        "headline": "Catalogue clair,\nalertes utiles",
        "subtitle": "Produits, catégories, seuils et ajustements\nsans tableur.",
        "bullets": [
            ("Catalogue", "Produits & catégories"),
            ("Seuils", "Alerte avant la rupture"),
            ("Mouvements", "Traçabilité des stocks"),
        ],
        "cta": "Maîtriser mon stock",
        "mock": "inventory",
        "accent": (0, 121, 107),
    },
    {
        "file": "affiche-module-clients-credit.png",
        "badge": "CLIENTS & CRÉDIT",
        "title": "Fidélisez\net recouvrez",
        "headline": "Fiches clients,\ndettes claires",
        "subtitle": "Historique d’achats, remboursements\net relances WhatsApp.",
        "bullets": [
            ("Fiche client", "Tout l’historique au même endroit"),
            ("Dettes", "Suivi et remboursements"),
            ("Relances", "WhatsApp en un tap"),
        ],
        "cta": "Gérer mes clients",
        "mock": "customers",
        "accent": (123, 31, 162),
    },
    {
        "file": "affiche-module-caisse.png",
        "badge": "GESTION DE CAISSE",
        "title": "Caisse claire,\nchaque jour",
        "headline": "Ouverture, suivi,\nclôture fiable",
        "subtitle": "Écarts visibles, équipe responsabilisée,\njournée bouclée sereinement.",
        "bullets": [
            ("Ouverture", "Fond de caisse enregistré"),
            ("Suivi", "Espèces, MoMo, crédit"),
            ("Clôture", "Bilan net de la journée"),
        ],
        "cta": "Sécuriser ma caisse",
        "mock": "cash",
        "accent": (230, 81, 0),
    },
    {
        "file": "affiche-module-depenses.png",
        "badge": "DÉPENSES",
        "title": "Voyez le\nbénéfice réel",
        "headline": "Charges suivies,\nmarges justes",
        "subtitle": "Enregistrez les dépenses du jour\npour un résultat commercial fiable.",
        "bullets": [
            ("Saisie rapide", "Catégories métier"),
            ("Lien caisse", "Impact sur la journée"),
            ("Clarté", "CA ≠ bénéfice"),
        ],
        "cta": "Suivre mes dépenses",
        "mock": "expenses",
        "accent": (183, 28, 28),
    },
    {
        "file": "affiche-module-statistiques.png",
        "badge": "STATISTIQUES",
        "title": "Pilotez en\nun regard",
        "headline": "Rapports utiles,\ndécisions rapides",
        "subtitle": "Top produits, période, tendances\net export PDF.",
        "bullets": [
            ("Périodes", "Jour, semaine, mois"),
            ("Top ventes", "Ce qui marche vraiment"),
            ("Export", "PDF pour archives & litiges"),
        ],
        "cta": "Voir mes stats",
        "mock": "stats",
        "accent": (21, 101, 192),
    },
    {
        "file": "affiche-module-calculateurs.png",
        "badge": "CALCULATEURS MÉTIERS",
        "title": "Carrelage,\npeinture, béton",
        "headline": "Estimez…\npuis vendez",
        "subtitle": "Quantités calculées, produit choisi,\npanier prêt en un tap.",
        "bullets": [
            ("Carrelage", "Surface → nombre de carreaux"),
            ("Peinture", "Murs & rendements"),
            ("Béton", "Dosages chantier"),
        ],
        "cta": "Calculer puis vendre",
        "mock": "calculators",
        "accent": GOLD,
    },
    {
        "file": "affiche-module-hors-ligne.png",
        "badge": "OFFLINE-FIRST",
        "title": "Même sans\nInternet",
        "headline": "Le commerce\nne s’arrête jamais",
        "subtitle": "Vendez partout. La synchronisation\nreprend dès que le réseau revient.",
        "bullets": [
            ("Hors ligne", "Ventes & stock locaux"),
            ("Sync auto", "File d’attente transparente"),
            ("Sauvegarde", "Google Drive chiffré"),
        ],
        "cta": "Travailler hors ligne",
        "mock": "offline",
        "accent": (2, 119, 189),
    },
    {
        "file": "affiche-module-equipe-securite.png",
        "badge": "ÉQUIPE & SÉCURITÉ",
        "title": "Équipe protégée,\nrôles clairs",
        "headline": "PIN, biométrie,\naudit complet",
        "subtitle": "Chaque action sensible est tracée.\nChacun voit seulement ce qu’il doit.",
        "bullets": [
            ("PIN / empreinte", "Accès sécurisé"),
            ("Rôles", "Patron, vendeur, lecteur"),
            ("Journal d’audit", "Qui a fait quoi, quand"),
        ],
        "cta": "Sécuriser mon équipe",
        "mock": "security",
        "accent": (55, 71, 79),
    },
    {
        "file": "affiche-module-multi-boutiques.png",
        "badge": "MULTI-BOUTIQUES",
        "title": "Plusieurs\npoints de vente",
        "headline": "Une app,\ntoutes vos boutiques",
        "subtitle": "Basculez de boutique en boutique\nsans perdre le fil.",
        "bullets": [
            ("Isolation", "Stock & ventes séparés"),
            ("Bascule rapide", "Changement en 1 tap"),
            ("Vision globale", "Prêt pour grandir"),
        ],
        "cta": "Gérer mes boutiques",
        "mock": "shops",
        "accent": (69, 90, 100),
    },
]


def _font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/segoeui.ttf"),
        ("C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/arial.ttf"),
        ("C:/Windows/Fonts/calibrib.ttf", "C:/Windows/Fonts/calibri.ttf"),
    )
    for bold_p, reg_p in candidates:
        path = bold_p if bold else reg_p
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def _lerp(a: tuple[int, ...], b: tuple[int, ...], t: float) -> tuple[int, ...]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def _bg() -> Image.Image:
    img = Image.new("RGB", (W, H), GREEN_DARK)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = _lerp(GREEN, GREEN_DEEP, t * 0.85)
        for x in range(W):
            # Soft vignette + diagonal warmth
            dx = (x / W) - 0.5
            warmth = 0.04 * math.sin((x + y) * 0.01)
            r = min(255, max(0, int(c[0] * (1 + warmth - abs(dx) * 0.08))))
            g = min(255, max(0, int(c[1] * (1 + warmth - abs(dx) * 0.05))))
            b = min(255, max(0, int(c[2] * (1 - abs(dx) * 0.04))))
            px[x, y] = (r, g, b)
    # Subtle geometric circles
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for i, (cx, cy, rad, a) in enumerate(
        [
            (-80, 180, 320, 28),
            (W + 40, 520, 280, 22),
            (160, H - 120, 260, 20),
            (W - 100, H - 400, 180, 18),
        ]
    ):
        d.ellipse(
            [cx - rad, cy - rad, cx + rad, cy + rad],
            outline=(*WHITE, a),
            width=2,
        )
        d.ellipse(
            [cx - rad * 0.7, cy - rad * 0.7, cx + rad * 0.7, cy + rad * 0.7],
            outline=(*GOLD, max(8, a // 2)),
            width=1,
        )
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def _paste_logo(canvas: Image.Image, size: int = 88, y: int = 40) -> int:
    logo = Image.open(LOGO_LIGHT).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    x = (W - size) // 2
    canvas.alpha_composite(logo, (x, y))
    return y + size


def _text_block(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    font: ImageFont.ImageFont,
    fill: tuple[int, ...],
    gap: int = 6,
    max_width: int | None = None,
) -> int:
    lines = text.split("\n")
    cy = y
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        x = (W - tw) / 2
        draw.text((x, cy), line, font=font, fill=fill)
        cy += th + gap
    return cy


def _rounded_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    radius: int,
    fill: tuple[int, ...] | None = None,
    outline: tuple[int, ...] | None = None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def _phone_frame(accent: tuple[int, int, int], mock: str) -> Image.Image:
    """Mockup téléphone avec UI synthétique du module."""
    pw, ph = 520, 640
    phone = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(phone)

    # Shadow
    shadow = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([18, 28, pw - 6, ph - 6], radius=48, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    phone = Image.alpha_composite(phone, shadow)
    d = ImageDraw.Draw(phone)

    # Body
    _rounded_rect(d, (24, 12, pw - 24, ph - 24), 46, fill=(24, 28, 27, 255))
    _rounded_rect(d, (36, 24, pw - 36, ph - 36), 38, fill=(*OFF_WHITE, 255))

    # Notch
    _rounded_rect(d, (pw / 2 - 58, 28, pw / 2 + 58, 46), 10, fill=(24, 28, 27, 255))

    # Status bar
    d.text((52, 52), "9:41", font=_font(16, False), fill=INK)
    d.text((pw - 120, 52), "ARIKE", font=_font(15, True), fill=GREEN)

    # Content area
    content = Image.new("RGBA", (pw - 88, ph - 120), (*OFF_WHITE, 255))
    cd = ImageDraw.Draw(content)
    _draw_mock_ui(cd, content.size[0], content.size[1], accent, mock)
    phone.alpha_composite(content, (44, 78))

    # Home indicator
    d = ImageDraw.Draw(phone)
    _rounded_rect(d, (pw / 2 - 40, ph - 58, pw / 2 + 40, ph - 50), 4, fill=(120, 130, 125, 180))
    return phone


def _draw_mock_ui(
    d: ImageDraw.ImageDraw,
    w: int,
    h: int,
    accent: tuple[int, int, int],
    mock: str,
) -> None:
    title_f = _font(22, True)
    body_f = _font(16, False)
    small_f = _font(14, False)
    big_f = _font(28, True)

    # Header bar
    d.rounded_rectangle([0, 0, w, 52], radius=12, fill=(*GREEN, 255))
    labels = {
        "hero": "Accueil",
        "dashboard": "Tableau de bord",
        "sales": "Nouvelle vente",
        "inventory": "Inventaire",
        "customers": "Clients",
        "cash": "Caisse du jour",
        "expenses": "Dépenses",
        "stats": "Statistiques",
        "calculators": "Calculateurs",
        "offline": "Mode hors ligne",
        "security": "Sécurité",
        "shops": "Mes boutiques",
    }
    d.text((14, 14), labels.get(mock, "ARIKE"), font=title_f, fill=WHITE)

    y = 68
    if mock in ("hero", "dashboard"):
        # KPI cards
        for i, (label, value) in enumerate(
            [("CA du jour", "248 500"), ("Ventes", "37"), ("Alertes", "3")]
        ):
            x0 = 8 + i * ((w - 24) // 3 + 4)
            x1 = x0 + (w - 24) // 3
            d.rounded_rectangle([x0, y, x1, y + 78], radius=14, fill=WHITE, outline=(*MUTED, 255))
            d.text((x0 + 10, y + 12), label, font=small_f, fill=INK_SOFT)
            d.text((x0 + 10, y + 36), value, font=_font(18, True), fill=GREEN)
        y += 98
        d.rounded_rectangle([8, y, w - 8, y + 56], radius=14, fill=(*accent, 255))
        d.text((24, y + 16), "＋  Nouvelle vente", font=title_f, fill=WHITE)
        y += 72
        for name, amt in [("Riz 25kg", "12 500"), ("Huile 1L", "2 800"), ("Savon", "500")]:
            d.rounded_rectangle([8, y, w - 8, y + 48], radius=12, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 14), name, font=body_f, fill=INK)
            d.text((w - 110, y + 14), amt, font=_font(16, True), fill=GREEN)
            y += 56

    elif mock == "sales":
        d.rounded_rectangle([8, y, w - 8, y + 44], radius=12, fill=WHITE, outline=(*MUTED, 255))
        d.text((20, y + 12), "🔍  Rechercher un produit", font=body_f, fill=INK_SOFT)
        y += 60
        for name, price, qty in [("Riz local 25kg", "12 500", "×2"), ("Huile rouge 1L", "2 800", "×1")]:
            d.rounded_rectangle([8, y, w - 8, y + 64], radius=14, fill=WHITE, outline=(*MUTED, 255))
            d.ellipse([20, y + 14, 56, y + 50], fill=(*accent, 40))
            d.text((68, y + 12), name, font=_font(16, True), fill=INK)
            d.text((68, y + 36), f"{price} F  {qty}", font=small_f, fill=INK_SOFT)
            y += 76
        d.rounded_rectangle([8, y, w - 8, y + 70], radius=16, fill=(*GREEN, 255))
        d.text((24, y + 12), "Total  27 800 FCFA", font=title_f, fill=WHITE)
        d.text((24, y + 40), "Encaisser  →", font=body_f, fill=(*GOLD_SOFT, 255))

    elif mock == "inventory":
        for name, stock, warn in [
            ("Riz 25kg", "42", False),
            ("Huile 1L", "8", True),
            ("Savon", "120", False),
            ("Sucre 1kg", "3", True),
        ]:
            d.rounded_rectangle([8, y, w - 8, y + 58], radius=14, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 10), name, font=_font(17, True), fill=INK)
            color = (183, 28, 28) if warn else GREEN
            d.text((20, y + 34), f"Stock : {stock}", font=small_f, fill=color)
            if warn:
                d.rounded_rectangle([w - 100, y + 16, w - 20, y + 42], radius=10, fill=(255, 235, 238))
                d.text((w - 90, y + 20), "Alerte", font=small_f, fill=(183, 28, 28))
            y += 70

    elif mock == "customers":
        for name, debt in [("Amina K.", "15 000"), ("Jean B.", "0"), ("Fatou D.", "42 500")]:
            d.rounded_rectangle([8, y, w - 8, y + 64], radius=14, fill=WHITE, outline=(*MUTED, 255))
            d.ellipse([20, y + 12, 60, y + 52], fill=(*accent, 50))
            d.text((28, y + 22), name[0], font=title_f, fill=accent)
            d.text((74, y + 12), name, font=_font(17, True), fill=INK)
            label = "À jour" if debt == "0" else f"Dette {debt} F"
            d.text((74, y + 36), label, font=small_f, fill=GREEN if debt == "0" else (183, 28, 28))
            y += 76

    elif mock == "cash":
        d.rounded_rectangle([8, y, w - 8, y + 100], radius=16, fill=WHITE, outline=(*MUTED, 255))
        d.text((24, y + 16), "Session ouverte", font=small_f, fill=INK_SOFT)
        d.text((24, y + 40), "Fond : 50 000 F", font=title_f, fill=INK)
        d.text((24, y + 70), "Espèces + MoMo + Crédit", font=body_f, fill=INK_SOFT)
        y += 120
        for label, val in [("Entrées", "+186 200"), ("Sorties", "−12 000"), ("Écart", "0")]:
            d.rounded_rectangle([8, y, w - 8, y + 48], radius=12, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 14), label, font=body_f, fill=INK)
            d.text((w - 140, y + 14), val, font=_font(16, True), fill=accent)
            y += 56

    elif mock == "expenses":
        for name, amt in [("Transport", "3 500"), ("Électricité", "8 000"), ("Emballages", "2 200")]:
            d.rounded_rectangle([8, y, w - 8, y + 56], radius=14, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 18), name, font=_font(17, True), fill=INK)
            d.text((w - 120, y + 18), f"−{amt}", font=_font(16, True), fill=accent)
            y += 68
        d.rounded_rectangle([8, y, w - 8, y + 60], radius=14, fill=(*GREEN, 255))
        d.text((24, y + 18), "Bénéfice estimé  41 300 F", font=title_f, fill=WHITE)

    elif mock == "stats":
        # Bars
        d.rounded_rectangle([8, y, w - 8, y + 160], radius=16, fill=WHITE, outline=(*MUTED, 255))
        bars = [0.45, 0.7, 0.55, 0.9, 0.65, 0.8, 0.5]
        base = y + 140
        for i, hgt in enumerate(bars):
            bh = int(100 * hgt)
            x0 = 28 + i * 54
            d.rounded_rectangle([x0, base - bh, x0 + 34, base], radius=6, fill=(*accent, 255))
        y += 180
        d.text((16, y), "Top : Riz 25kg  ·  Huile  ·  Savon", font=body_f, fill=INK_SOFT)

    elif mock == "calculators":
        d.text((16, y), "Calculateur carrelage", font=title_f, fill=INK)
        y += 40
        for label, val in [("Longueur (m)", "5,20"), ("Largeur (m)", "3,80"), ("Format (cm)", "60×60")]:
            d.rounded_rectangle([8, y, w - 8, y + 52], radius=12, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 8), label, font=small_f, fill=INK_SOFT)
            d.text((20, y + 26), val, font=_font(18, True), fill=INK)
            y += 62
        d.rounded_rectangle([8, y, w - 8, y + 70], radius=16, fill=(*accent, 255))
        d.text((24, y + 12), "56 carreaux", font=big_f, fill=WHITE)
        d.text((24, y + 44), "Vendre maintenant  →", font=body_f, fill=WHITE)

    elif mock == "offline":
        d.rounded_rectangle([8, y, w - 8, y + 90], radius=16, fill=(255, 243, 224))
        d.text((24, y + 20), "☁  Hors ligne", font=title_f, fill=(230, 81, 0))
        d.text((24, y + 52), "3 opérations en attente de sync", font=body_f, fill=INK)
        y += 110
        for t in ["Vente #1842 enregistrée", "Stock ajusté (Huile)", "Client ajouté"]:
            d.rounded_rectangle([8, y, w - 8, y + 48], radius=12, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 14), f"✓  {t}", font=body_f, fill=GREEN)
            y += 56

    elif mock == "security":
        d.rounded_rectangle([8, y, w - 8, y + 100], radius=16, fill=WHITE, outline=(*MUTED, 255))
        d.text((24, y + 18), "●●●●", font=big_f, fill=INK)
        d.text((24, y + 58), "PIN boutique actif", font=body_f, fill=INK_SOFT)
        y += 120
        for role in ["Patron — accès total", "Vendeur — ventes & stock", "Lecteur — consultation"]:
            d.rounded_rectangle([8, y, w - 8, y + 48], radius=12, fill=WHITE, outline=(*MUTED, 255))
            d.text((20, y + 14), role, font=body_f, fill=INK)
            y += 56

    else:  # shops
        for name, city in [("Boutique Centre", "Cotonou"), ("Dépôt Akpakpa", "Cotonou"), ("Point Parakou", "Parakou")]:
            d.rounded_rectangle([8, y, w - 8, y + 64], radius=14, fill=WHITE, outline=(*MUTED, 255))
            d.rounded_rectangle([20, y + 16, 52, y + 48], radius=8, fill=(*accent, 40))
            d.text((64, y + 12), name, font=_font(17, True), fill=INK)
            d.text((64, y + 36), city, font=small_f, fill=INK_SOFT)
            y += 76


def _bullets(
    canvas: Image.Image,
    bullets: list[tuple[str, str]],
    y: int,
    accent: tuple[int, int, int],
) -> int:
    draw = ImageDraw.Draw(canvas)
    title_f = _font(22, True)
    body_f = _font(18, False)
    card_w = W - 96
    x0 = 48
    for title, desc in bullets:
        h = 78
        # soft card
        card = Image.new("RGBA", (card_w, h), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card)
        cd.rounded_rectangle([0, 0, card_w - 1, h - 1], radius=18, fill=(255, 255, 255, 22))
        cd.rounded_rectangle([0, 0, card_w - 1, h - 1], radius=18, outline=(255, 255, 255, 40), width=1)
        # accent bar
        cd.rounded_rectangle([0, 14, 8, h - 14], radius=4, fill=(*accent, 255))
        # gold dot
        cd.ellipse([22, 26, 42, 46], fill=(*GOLD, 255))
        cd.text((56, 14), title, font=title_f, fill=WHITE)
        cd.text((56, 42), desc, font=body_f, fill=MUTED)
        canvas.alpha_composite(card, (x0, y))
        y += h + 12
    return y


def build_poster(spec: dict) -> Image.Image:
    canvas = _bg()
    draw = ImageDraw.Draw(canvas)
    accent = spec["accent"]

    y = _paste_logo(canvas, 92, 36) + 14

    # Badge
    badge = spec["badge"]
    bf = _font(20, True)
    bb = draw.textbbox((0, 0), badge, font=bf)
    bw, bh = bb[2] - bb[0], bb[3] - bb[1]
    pad_x, pad_y = 20, 10
    pill = [
        (W - bw) / 2 - pad_x,
        y,
        (W + bw) / 2 + pad_x,
        y + bh + pad_y * 2,
    ]
    _rounded_rect(draw, pill, 18, fill=(*GOLD, 255))
    draw.text(((W - bw) / 2, y + pad_y - 1), badge, font=bf, fill=GREEN_DEEP)
    y = int(pill[3]) + 20

    # Title
    y = _text_block(draw, spec["title"], y, _font(56, True), WHITE, gap=4)
    y += 8
    # Gold rule
    _rounded_rect(draw, ((W - 100) / 2, y, (W + 100) / 2, y + 5), 3, fill=(*GOLD, 255))
    y += 18

    # Headline (benefit)
    y = _text_block(draw, spec["headline"], y, _font(34, True), (*GOLD_SOFT, 255), gap=4)
    y += 10
    y = _text_block(draw, spec["subtitle"], y, _font(22, False), MUTED, gap=4)
    y += 18

    # Phone mockup
    phone = _phone_frame(accent, spec["mock"])
    target_h = 440
    scale = target_h / phone.size[1]
    tw, th = int(phone.size[0] * scale), int(phone.size[1] * scale)
    phone = phone.resize((tw, th), Image.Resampling.LANCZOS)
    canvas.alpha_composite(phone, ((W - tw) // 2, y))
    y += th + 12

    # Bullets (si place restante)
    if y + 260 < H - 100:
        y = _bullets(canvas, spec["bullets"], y, accent)
    else:
        # version compacte : 2 bullets max
        y = _bullets(canvas, spec["bullets"][:2], y, accent)

    # CTA
    cta = spec["cta"]
    cf = _font(26, True)
    cb = draw.textbbox((0, 0), cta, font=cf)
    cw, ch = cb[2] - cb[0], cb[3] - cb[1]
    btn_y = min(y + 8, H - 110)
    btn = [
        (W - cw) / 2 - 40,
        btn_y,
        (W + cw) / 2 + 40,
        btn_y + ch + 28,
    ]
    _rounded_rect(draw, btn, 26, fill=(*GOLD, 255))
    draw.text(((W - cw) / 2, btn_y + 12), cta, font=cf, fill=GREEN_DEEP)

    # Footer brand
    foot = "ARIKE  ·  Gestion commerciale — Bénin"
    ff = _font(18, False)
    fb = draw.textbbox((0, 0), foot, font=ff)
    draw.text(((W - (fb[2] - fb[0])) / 2, H - 42), foot, font=ff, fill=MUTED)

    return canvas.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not LOGO_LIGHT.exists():
        raise FileNotFoundError(LOGO_LIGHT)

    for spec in POSTERS:
        poster = build_poster(spec)
        dest = OUT / spec["file"]
        poster.save(dest, quality=95, optimize=True)
        print(f"OK  {dest.name}")
        alias = spec.get("alias")
        if alias:
            poster.save(OUT / alias, quality=95, optimize=True)
            print(f"    alias -> {alias}")

    print(f"\n{len(POSTERS)} affiches dans {OUT}")


if __name__ == "__main__":
    main()
