from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


OUT_DIR = Path(__file__).resolve().parent
S = 2
W, H = 390 * S, 844 * S

FONT_SERIF = "/System/Library/Fonts/Supplemental/Songti.ttc"
FONT_SANS = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_LATIN_ITALIC = "/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf"
FONT_LATIN_BOLD = "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf"
FONT_MONO = "/System/Library/Fonts/Menlo.ttc"
ICON_PATH = OUT_DIR.parent / "assets/logo/app-icon-1024.png"


COL = {
    "night0": "#050913",
    "night1": "#071225",
    "night2": "#10213A",
    "ink": "#132437",
    "ink2": "#24302D",
    "mist": "#91A0B3",
    "mist2": "#B8C1C9",
    "cream": "#F2E7D0",
    "paper": "#EBDCBC",
    "paper2": "#F7F1E6",
    "gold": "#C7A260",
    "brass": "#A8874B",
    "coral": "#D87561",
    "line": "#D8C9AA",
    "green": "#6E8A7C",
}


def c(hex_color: str, alpha: int = 255):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def font(path: str, size: int, index: int = 0):
    try:
        return ImageFont.truetype(path, size * S, index=index)
    except Exception:
        return ImageFont.truetype(FONT_SANS, size * S)


def sans(size: int):
    return font(FONT_SANS, size)


def serif(size: int):
    return font(FONT_SERIF, size)


def italic(size: int):
    return font(FONT_LATIN_ITALIC, size)


def mono(size: int):
    return font(FONT_MONO, size)


def bold(size: int):
    return font(FONT_LATIN_BOLD, size)


def xy(v: float) -> int:
    return int(round(v * S))


def box(x: float, y: float, w: float, h: float):
    return (xy(x), xy(y), xy(x + w), xy(y + h))


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt) -> tuple[int, int]:
    b = draw.textbbox((0, 0), text, font=fnt)
    return b[2] - b[0], b[3] - b[1]


def draw_text(
    draw: ImageDraw.ImageDraw,
    pos: tuple[float, float],
    text: str,
    fnt,
    fill,
    anchor: str = "la",
    spacing: int = 4,
    align: str = "left",
):
    draw.text((xy(pos[0]), xy(pos[1])), text, font=fnt, fill=fill, anchor=anchor, spacing=xy(spacing), align=align)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt, max_w: int) -> list[str]:
    lines: list[str] = []
    cur = ""
    for ch in text:
        trial = cur + ch
        if text_size(draw, trial, fnt)[0] <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = ch
    if cur:
        lines.append(cur)
    return lines


def rounded(draw, rect, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(rect, radius=xy(radius), fill=fill, outline=outline, width=xy(width))


def gradient_bg() -> Image.Image:
    img = Image.new("RGBA", (W, H), c(COL["night0"]))
    pix = img.load()
    top = c(COL["night0"])
    mid = c(COL["night1"])
    bot = c(COL["night2"])
    for y in range(H):
        t = y / (H - 1)
        if t < 0.55:
            tt = t / 0.55
            src = tuple(int(top[i] * (1 - tt) + mid[i] * tt) for i in range(4))
        else:
            tt = (t - 0.55) / 0.45
            src = tuple(int(mid[i] * (1 - tt) + bot[i] * tt) for i in range(4))
        for x in range(W):
            pix[x, y] = src

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(120, 0, -1):
        alpha = int(35 * (i / 120) ** 2)
        gd.ellipse((W // 2 - i * S * 3, H - i * S * 2, W // 2 + i * S * 3, H + i * S * 4), fill=c(COL["gold"], alpha))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(xy(18))))

    d = ImageDraw.Draw(img)
    random.seed(9)
    for _ in range(70):
        x = random.randint(xy(24), W - xy(24))
        y = random.randint(xy(22), xy(410))
        r = random.choice([1, 1, 1, 2])
        d.ellipse((x, y, x + r, y + r), fill=(255, 255, 255, random.randint(38, 100)))
    return img


def paper_texture(size: tuple[int, int], fill="#F2E7D0") -> Image.Image:
    img = Image.new("RGBA", size, c(fill))
    px = img.load()
    random.seed(size[0] * 37 + size[1])
    for _ in range(int(size[0] * size[1] * 0.018)):
        x = random.randrange(size[0])
        y = random.randrange(size[1])
        delta = random.randint(-12, 10)
        base = px[x, y]
        px[x, y] = tuple(max(0, min(255, base[i] + delta)) for i in range(3)) + (255,)
    lines = Image.new("RGBA", size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for y in range(xy(20), size[1], xy(22)):
        ld.line((xy(14), y, size[0] - xy(14), y), fill=c("#D8C9AA", 45), width=1)
    img.alpha_composite(lines)
    return img


def paste_round(base: Image.Image, overlay: Image.Image, rect, radius):
    x1, y1, x2, y2 = rect
    overlay = overlay.resize((x2 - x1, y2 - y1), Image.LANCZOS)
    mask = Image.new("L", overlay.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, overlay.size[0], overlay.size[1]), radius=xy(radius), fill=255)
    base.paste(overlay, (x1, y1), mask)


def shadow(base: Image.Image, rect, radius, alpha=70, blur=22, yoff=10):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x1, y1, x2, y2 = rect
    d.rounded_rectangle((x1, y1 + xy(yoff), x2, y2 + xy(yoff)), radius=xy(radius), fill=(0, 0, 0, alpha))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(xy(blur))))


def status_bar(draw: ImageDraw.ImageDraw, time="14:06"):
    draw_text(draw, (28, 22), time, sans(14), c(COL["paper2"], 230))
    draw.rounded_rectangle(box(328, 24, 28, 12), radius=xy(6), outline=c(COL["paper2"], 180), width=xy(1))
    draw.rounded_rectangle(box(331, 27, 20, 6), radius=xy(3), fill=c("#7FC56F", 230))
    for i, h in enumerate([5, 8, 11]):
        draw.rounded_rectangle(box(292 + i * 6, 31 - h, 3, h), radius=xy(1.5), fill=c(COL["paper2"], 190))
    draw.arc(box(314, 21, 18, 18), start=215, end=325, fill=c(COL["paper2"], 190), width=xy(1.2))
    draw.arc(box(318, 25, 10, 10), start=215, end=325, fill=c(COL["paper2"], 190), width=xy(1.2))


def header(draw: ImageDraw.ImageDraw, title="Head in the Clouds", subtitle="今天"):
    draw_text(draw, (30, 78), title, italic(27), c(COL["cream"]))
    draw_text(draw, (31, 112), subtitle, serif(13), c(COL["gold"], 205))
    rounded(draw, box(333, 74, 34, 34), 17, c("#F7F1E6", 238), outline=c("#D8C9AA", 120), width=1)
    cx, cy = 350, 91
    draw.ellipse((xy(cx - 7), xy(cy - 7), xy(cx + 7), xy(cy + 7)), outline=c(COL["ink"], 190), width=xy(1.4))
    draw.ellipse((xy(cx - 2), xy(cy - 2), xy(cx + 2), xy(cy + 2)), fill=c(COL["ink"], 190))
    for a in range(0, 360, 60):
        r1, r2 = 10, 13
        x1 = cx + math.cos(math.radians(a)) * r1
        y1 = cy + math.sin(math.radians(a)) * r1
        x2 = cx + math.cos(math.radians(a)) * r2
        y2 = cy + math.sin(math.radians(a)) * r2
        draw.line((xy(x1), xy(y1), xy(x2), xy(y2)), fill=c(COL["ink"], 170), width=xy(1))


def postmark(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, ink="#132437", alpha=105, label="云上\n心事"):
    draw.ellipse((xy(cx - r), xy(cy - r), xy(cx + r), xy(cy + r)), outline=c(ink, alpha), width=xy(1.2))
    draw.ellipse((xy(cx - r + 5), xy(cy - r + 5), xy(cx + r - 5), xy(cy + r - 5)), outline=c(ink, alpha - 20), width=xy(1))
    draw_text(draw, (cx, cy - 8), "Head", italic(7), c(ink, alpha), anchor="mm")
    for i, line in enumerate(label.split("\n")):
        draw_text(draw, (cx, cy + 1 + i * 10), line, serif(8), c(ink, alpha), anchor="mm")


def route_line(draw: ImageDraw.ImageDraw, x1, y1, x2, y2, ink="#132437", alpha=150):
    draw.line((xy(x1), xy(y1), xy(x2), xy(y2)), fill=c(ink, alpha), width=xy(1.2))
    draw.ellipse((xy(x1 - 2), xy(y1 - 2), xy(x1 + 2), xy(y1 + 2)), fill=c(ink, alpha))
    draw.ellipse((xy(x2 - 2), xy(y2 - 2), xy(x2 + 2), xy(y2 + 2)), fill=c(ink, alpha))
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    angle = math.atan2(y2 - y1, x2 - x1)
    pts = []
    for dx, dy in [(0, -5), (12, 0), (0, 5), (3, 0)]:
        rx = dx * math.cos(angle) - dy * math.sin(angle)
        ry = dx * math.sin(angle) + dy * math.cos(angle)
        pts.append((xy(mx + rx), xy(my + ry)))
    draw.polygon(pts, fill=c(ink, alpha))


def cloud_card(base: Image.Image, x: float, y: float, w: float, h: float, quote: str, mood="奔赴", compact=False, log=False):
    d = ImageDraw.Draw(base)
    rect = box(x, y, w, h)
    shadow(base, rect, 12, alpha=50, blur=18, yoff=8)
    rounded(d, rect, 12, c(COL["ink"]), outline=c("#24435E", 145), width=1)
    inner = box(x + 10, y + 10, w - 20, h - 20)

    if compact:
        if log:
            rounded(d, inner, 7, c("#132437"), outline=c(COL["gold"], 85), width=1)
            draw_text(d, (x + 18, y + 24), "FLIGHT LOG", mono(5), c(COL["gold"], 185))
            d.line((xy(x + 18), xy(y + 43), xy(x + w - 18), xy(y + 43)), fill=c(COL["gold"], 90), width=xy(1))
            qfont = serif(8)
            quote_lines = wrap_text(d, quote, qfont, xy(w - 36))
            yy = y + 54
            for line in quote_lines[:3]:
                draw_text(d, (x + 18, yy), line, qfont, c(COL["cream"], 230))
                yy += 13
            return

        paper = paper_texture((xy(w - 20), xy(h - 20)), COL["cream"])
        paste_round(base, paper, inner, 7)
        d = ImageDraw.Draw(base)
        draw_text(d, (x + 18, y + 23), "MU5301", mono(5), c(COL["ink"], 205))
        draw_text(d, (x + 18, y + 38), "SHA → CTU", mono(4), c(COL["ink"], 165))
        qfont = serif(6 if w < 70 else 8)
        quote_lines = wrap_text(d, quote.replace("\n", ""), qfont, xy(w - 36))
        yy = y + 56
        for line in quote_lines[: 2 if w < 70 else 3]:
            draw_text(d, (x + 18, yy), line, qfont, c(COL["ink"], 220))
            yy += 10 if w < 70 else 13
        postmark(d, x + w - 22, y + 35, 10 if w < 70 else 13, alpha=70)
        return

    if log:
        rounded(d, inner, 8, c("#132437"), outline=c(COL["gold"], 80), width=1)
        d.line((xy(x + 28), xy(y + 55), xy(x + w - 28), xy(y + 55)), fill=c(COL["gold"], 70), width=xy(1))
        draw_text(d, (x + 28, y + 30), "FLIGHT LOG", mono(8), c(COL["gold"], 185))
        qfont = serif(18 if not compact else 10)
        quote_lines = wrap_text(d, quote, qfont, xy(w - 56))
        yy = y + 78
        for line in quote_lines[:3]:
            draw_text(d, (x + 28, yy), line, qfont, c(COL["cream"]))
            yy += 24 if not compact else 15
        draw_text(d, (x + 28, y + h - 48), "MU5301 · 延误 · 私人明信片", mono(8), c(COL["mist"], 175))
        return

    paper = paper_texture((xy(w - 20), xy(h - 20)), COL["cream"])
    paste_round(base, paper, inner, 8)
    d = ImageDraw.Draw(base)
    draw_text(d, (x + 24, y + 26), "MU5301", mono(6 if compact else 12), c(COL["ink"], 205))
    draw_text(d, (x + 24, y + 43), "SHA → CTU", mono(5 if compact else 10), c(COL["ink"], 170))
    draw_text(d, (x + 24, y + 60), f"2026.05.19 · {mood}", sans(5 if compact else 10), c(COL["ink"], 155))
    postmark(d, x + w - 52, y + 48, 25 if not compact else 18, alpha=95)
    d.line((xy(x + 24), xy(y + 88), xy(x + w - 24), xy(y + 88)), fill=c(COL["line"], 135), width=xy(1))
    if compact:
        quote_size = 9 if w < 95 else 11
    else:
        quote_size = 25 if w < 320 else 30
    quote_lines = wrap_text(d, quote, serif(quote_size), xy(w - 62))
    yy = y + 112
    for line in quote_lines[:3]:
        draw_text(d, (x + 28, yy), line, serif(quote_size), c(COL["ink"], 235))
        yy += quote_size + (8 if compact else 13)
    route_line(d, x + 92, y + h - 93, x + w - 100, y + h - 122, alpha=175)
    draw_text(d, (x + 73, y + h - 70), "SHA", mono(8), c(COL["ink"], 165))
    draw_text(d, (x + w - 88, y + h - 102), "CTU", mono(8), c(COL["ink"], 165))
    if not compact:
        draw_text(d, (x + 28, y + h - 34), "Head in the Clouds / 云上心事", italic(8), c(COL["ink"], 130))


def action_chip(draw, x, y, w, title, sub=None, active=False):
    fill = c(COL["paper2"], 242) if active else c("#F4EAD9", 230)
    rounded(draw, box(x, y, w, 54), 18, fill, outline=c("#D5C5A4", 125), width=1)
    draw_text(draw, (x + 16, y + 16), title, serif(12), c(COL["ink"], 220))
    if sub:
        draw_text(draw, (x + 16, y + 34), sub, sans(8), c(COL["ink"], 125))


def shell(draw, active="今天"):
    x, y, w, h = 27, 758, 336, 62
    rounded(draw, box(x, y, w, h), 26, c("#F7F1E6", 242), outline=c("#D8C9AA", 135), width=1)
    entries = [("今天", "·", x + 52), ("飞行册", "·", x + 138), ("发现", "·", x + 282)]
    for label, dot, cx in entries:
        color = c(COL["ink"]) if label == active else c(COL["mist"], 220)
        draw_text(draw, (cx, y + 19), dot, sans(22), c(COL["gold"] if label == active else COL["mist"], 210), anchor="mm")
        draw_text(draw, (cx, y + 43), label, sans(10), color, anchor="mm")
    cx = x + w / 2
    draw.ellipse((xy(cx - 27), xy(y - 17), xy(cx + 27), xy(y + 37)), fill=c(COL["ink"]), outline=c(COL["gold"], 210), width=xy(2))
    draw_text(draw, (cx, y + 10), "写", serif(20), c(COL["cream"]), anchor="mm")
    draw_text(draw, (cx, y + 45), "写下", sans(9), c(COL["ink"]) if active == "写" else c(COL["mist"], 220), anchor="mm")


def screen_base(title="Head in the Clouds", subtitle="今天"):
    img = gradient_bg()
    d = ImageDraw.Draw(img)
    status_bar(d)
    header(d, title, subtitle)
    return img, d


def today_returning() -> Image.Image:
    img, d = screen_base(subtitle="今天")
    draw_text(d, (30, 152), "最近的云上心事", sans(11), c(COL["gold"], 190))
    rounded(d, box(28, 172, 334, 164), 22, c("#F7F1E6", 238), outline=c("#D8C9AA", 120), width=1)
    draw_text(d, (52, 202), "我把没有说出口的话\n带过了云层。", serif(23), c(COL["ink"]), spacing=9)
    draw_text(d, (52, 280), "MU5301 · SHA → CTU · 2026.05.19", mono(8), c(COL["ink"], 135))
    cloud_card(img, 260, 195, 78, 100, "我把没有\n说出口的话，\n带过了云层。", compact=True)
    rounded(d, box(52, 302, 88, 24), 12, c(COL["ink"]), outline=None)
    draw_text(d, (96, 314), "查看这张卡", sans(9), c(COL["cream"]), anchor="mm")
    d.line((xy(30), xy(364), xy(360), xy(364)), fill=c("#D8C9AA", 60), width=xy(1))
    draw_text(d, (30, 408), "下一次飞行前\n先留一句", serif(31), c(COL["cream"]), spacing=9)
    draw_text(d, (30, 497), "写作是主路径；航班和提醒只在需要时出现。", sans(12), c(COL["mist"], 170))
    action_chip(d, 30, 548, 155, "添加航班", "扫描机牌 / 手输")
    action_chip(d, 205, 548, 155, "登机提醒", "起飞前 30 分钟")
    rounded(d, box(30, 630, 330, 74), 22, c("#08162A", 222), outline=c("#2B4968", 110), width=1)
    draw_text(d, (52, 654), "航班信息可以稍后补", serif(17), c(COL["cream"]))
    draw_text(d, (52, 681), "验证后才能进入同班机；私人卡不受影响。", sans(10), c(COL["mist"], 165))
    shell(d, "今天")
    return img


def today_empty() -> Image.Image:
    img, d = screen_base(subtitle="今天这趟，先留一句")
    cloud_card(img, 45, 168, 300, 230, "我在起飞前最后一次看见这座城市。", compact=False)
    draw_text(d, (30, 442), "还没有第一张卡", serif(30), c(COL["cream"]))
    draw_text(d, (30, 492), "一句话就够；航班信息可以稍后补。", sans(13), c(COL["mist"], 180))
    rounded(d, box(30, 542, 330, 58), 29, c(COL["gold"]), outline=None)
    draw_text(d, (195, 571), "写下这一趟", sans(16), c("#071225"), anchor="mm")
    action_chip(d, 30, 628, 155, "添加航班", "可选")
    action_chip(d, 205, 628, 155, "看看别人", "只读浏览")
    shell(d, "今天")
    return img


def flightbook() -> Image.Image:
    img, d = screen_base(subtitle="我的飞行册")
    draw_text(d, (30, 156), "我的飞行册", serif(34), c(COL["cream"]))
    draw_text(d, (31, 206), "4 张卡 · Guest 本机保存", sans(12), c(COL["mist"], 170))
    cards = [
        (34, 254, "我把没有\n说出口的话，\n带过了云层。", "MU5301 · 奔赴", False),
        (207, 254, "飞机晚点了，\n累死。", "航班待确认", True),
        (34, 476, "终于落地，\n也终于松了\n一口气。", "HKG → SHA", False),
        (207, 476, "这趟只想睡觉。", "私人民信片", True),
    ]
    for x, y, quote, meta, log in cards:
        rounded(d, box(x, y, 145, 188), 19, c("#F7F1E6", 246), outline=c("#D8C9AA", 120), width=1)
        cloud_card(img, x + 16, y + 18, 113, 130, quote, compact=True, log=log)
        draw_text(d, (x + 16, y + 166), meta, sans(8), c(COL["ink"], 145))
    shell(d, "飞行册")
    return img


def compose() -> Image.Image:
    img = gradient_bg()
    d = ImageDraw.Draw(img)
    status_bar(d)
    draw_text(d, (30, 82), "写下这一趟", serif(28), c(COL["cream"]))
    draw_text(d, (30, 118), "未添加航班 · 稍后补", sans(12), c(COL["gold"], 205))
    draw_text(d, (348, 88), "取消", sans(12), c(COL["mist"], 190), anchor="ra")
    draw_text(d, (30, 174), "这次飞行，\n我只想说：", serif(34), c(COL["cream"]), spacing=8)
    shadow(img, box(30, 302, 330, 250), 22, alpha=55, blur=18, yoff=8)
    rounded(d, box(30, 302, 330, 250), 22, c(COL["paper2"], 250), outline=c("#D8C9AA", 160), width=1)
    draw_text(d, (58, 338), "比如：我把没有说出口的话，\n带过了云层。", serif(18), c(COL["ink"], 150), spacing=9)
    for yy in [396, 438, 480]:
        d.line((xy(58), xy(yy), xy(333), xy(yy)), fill=c("#D8C9AA", 130), width=xy(1))
    draw_text(d, (58, 522), "草稿已保存", sans(10), c(COL["green"], 210))
    action_chip(d, 30, 582, 94, "一句话", active=True)
    action_chip(d, 148, 582, 94, "模板")
    action_chip(d, 266, 582, 94, "语音")
    rounded(d, box(30, 692, 330, 58), 29, c(COL["gold"]), outline=None)
    draw_text(d, (195, 721), "生成私人明信片", sans(16), c("#071225"), anchor="mm")
    draw_text(d, (195, 778), "完成后回到「今天」", sans(10), c(COL["mist"], 130), anchor="mm")
    return img


def discover() -> Image.Image:
    img, d = screen_base(subtitle="发现")
    draw_text(d, (30, 154), "别人留下的", serif(34), c(COL["cream"]))
    draw_text(d, (30, 202), "只读浏览；评论只在本航班开放", sans(12), c(COL["mist"], 170))
    for i, (label, active) in enumerate([("同航线", True), ("目的地", False), ("此刻", False)]):
        rounded(d, box(30 + i * 102, 238, 82, 34), 17, c(COL["paper2"] if active else "#F3E8D7", 238), outline=c("#D8C9AA", 125), width=1)
        draw_text(d, (71 + i * 102, 255), label, sans(11), c(COL["ink"] if active else COL["mist"], 215), anchor="mm")
    feed = [
        (30, 306, "有人在云层上，\n把沉默放轻了。", "SHA → CTU · 靠窗的人", False),
        (30, 468, "终于落地，\n也终于松了一口气。", "HKG → SHA · 同机乘客", False),
        (30, 630, "飞机晚点了，累死。", "航班待确认 · 私人卡", True),
    ]
    for x, y, quote, meta, log in feed:
        rounded(d, box(x, y, 330, 128), 20, c("#F7F1E6", 242), outline=c("#D8C9AA", 115), width=1)
        draw_text(d, (54, y + 34), quote, serif(20), c(COL["ink"], 230), spacing=8)
        draw_text(d, (54, y + 95), meta, sans(8), c(COL["ink"], 125))
        cloud_card(img, 278, y + 24, 60, 78, "我把没有\n说出口的话。", compact=True, log=log)
    shell(d, "发现")
    return img


def save_screen(name: str, img: Image.Image):
    path = OUT_DIR / name
    img.convert("RGB").save(path, quality=96)
    return path


def contact_sheet(paths: list[Path]):
    thumb_w, thumb_h = W, H
    margin = xy(34)
    label_h = xy(42)
    sheet_w = thumb_w * 2 + margin * 3
    sheet_h = (thumb_h + label_h) * 3 + margin * 4
    sheet = Image.new("RGBA", (sheet_w, sheet_h), c("#F2EDE4"))
    d = ImageDraw.Draw(sheet)
    draw_text(d, (34, 24), "High-fidelity App Shell Review Candidate · Today / Flight Book / Write / Discover", sans(18), c(COL["ink"]))
    labels = ["Today · Returning", "Today · Empty", "Flight Book", "Write / Compose", "Discover"]
    for i, path in enumerate(paths):
        row, col = divmod(i, 2)
        x = margin + col * (thumb_w + margin)
        y = margin + xy(42) + row * (thumb_h + label_h)
        draw_text(d, (x / S, y / S - 20), labels[i], sans(12), c(COL["ink"], 185))
        im = Image.open(path).convert("RGBA")
        sheet.alpha_composite(im, (x, y))
    out = OUT_DIR / "high-fidelity-shell-contact-sheet-2026-06-26.png"
    sheet.convert("RGB").save(out, quality=96)
    return out


def main():
    outputs = [
        save_screen("high-fidelity-shell-today-returning-2026-06-26.png", today_returning()),
        save_screen("high-fidelity-shell-today-empty-2026-06-26.png", today_empty()),
        save_screen("high-fidelity-shell-flightbook-2026-06-26.png", flightbook()),
        save_screen("high-fidelity-shell-compose-2026-06-26.png", compose()),
        save_screen("high-fidelity-shell-discover-2026-06-26.png", discover()),
    ]
    out = contact_sheet(outputs)
    for p in outputs + [out]:
        print(p)


if __name__ == "__main__":
    main()
