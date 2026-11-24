from PIL import Image, ImageDraw, ImageFont

def pill(img, cx, cy, w, h, text, font_px):
    d = ImageDraw.Draw(img)
    x0, y0 = cx - w // 2, cy - h // 2
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=h // 2, fill=(245, 184, 61, 255))
    f = ImageFont.truetype("fonts/Poppins-800.ttf", font_px)
    bb = d.textbbox((0, 0), text, font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text((cx - tw / 2 - bb[0], cy - th / 2 - bb[1]), text, font=f, fill=(42, 10, 24, 255))

full = Image.open("icons/app_icon_1024.png").convert("RGBA")
pill(full, 512, 820, 360, 112, "DEMO", 72)
full.convert("RGB").save("icons/app_icon_preview_1024.png")

fg = Image.open("icons/adaptive_fg.png").convert("RGBA")
pill(fg, 216, 300, 120, 38, "DEMO", 24)
fg.save("icons/adaptive_fg_preview.png")

bg = Image.open("icons/adaptive_bg.png").convert("RGBA")
comp = bg.copy(); comp.alpha_composite(fg)
mask = Image.new("L", comp.size, 0); ImageDraw.Draw(mask).ellipse([36, 36, 396, 396], fill=255)
circle = Image.new("RGBA", comp.size, (255, 255, 255, 255)); circle.paste(comp, (0, 0), mask)
prev = Image.new("RGB", (1024 // 2 + 432 + 30, 512), (255, 255, 255))
prev.paste(full.convert("RGB").resize((512, 512)), (0, 0)); prev.paste(circle.convert("RGB"), (542, 40))
prev.save("renders/icon_preview_variant.jpg", quality=88)
print("ok")
