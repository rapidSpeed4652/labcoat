import os
import math
from PIL import Image, ImageDraw

TEX_DIR = "/home/koundinyag/Projects/LH1/assets/textures"

def gen_console_desk():
    size = (1024, 1024)
    img = Image.new("RGB", size, (35, 38, 44))
    draw = ImageDraw.Draw(img)
    
    # Metal console surface framing
    draw.rectangle([10, 10, 1014, 1014], outline=(20, 22, 26), width=6)
    
    # SECTION 1: Dual Oscilloscope Screens
    for ox, name in [(60, "PRIMARY LUNAR RETURN"), (540, "PERSEUS VOID DETECTOR")]:
        # Screen Bezel
        draw.rectangle([ox, 60, ox + 420, 440], fill=(15, 18, 22), outline=(50, 55, 62), width=6)
        # Circular CRT Screen
        draw.ellipse([ox + 40, 90, ox + 380, 410], fill=(5, 25, 12), outline=(30, 180, 60), width=4)
        # Scope Grid
        for gx in range(ox + 80, ox + 360, 40):
            draw.line([(gx, 100), (gx, 400)], fill=(10, 70, 25), width=1)
        for gy in range(120, 380, 40):
            draw.line([(ox + 60, gy), (ox + 360, gy)], fill=(10, 70, 25), width=1)
        # Laser pulse waveform
        pts = []
        for x in range(ox + 60, ox + 360):
            t = (x - ox - 60) * 0.05
            y = 250 - int(60 * math.sin(t) * math.exp(-((t - 7)**2) / 4.0)) if "PRIMARY" in name else 250 - int(45 * math.sin(t * 3.5) + 20 * math.cos(t * 7.2))
            pts.append((x, y))
        draw.line(pts, fill=(80, 255, 130), width=3)
        draw.text((ox + 50, 415), name, fill=(200, 220, 210))
    
    # SECTION 2: VU Analog Meters (Capacitors, Voltage, Optical Flux)
    for i, label in enumerate(["LASER FLUX", "CAPACITOR A", "CAPACITOR B", "RETURN BEAM"]):
        mx = 60 + i * 230
        my = 480
        draw.rectangle([mx, my, mx + 210, my + 140], fill=(235, 230, 215), outline=(20, 22, 26), width=4)
        # Gauge arc
        draw.arc([mx + 15, my + 15, mx + 195, my + 180], 200, 340, fill=(40, 40, 40), width=3)
        # Red danger zone
        draw.arc([mx + 15, my + 15, mx + 195, my + 180], 290, 340, fill=(200, 30, 30), width=5)
        # Needle
        angle = 240 + i * 25
        rad = math.radians(angle)
        cx, cy = mx + 105, my + 115
        nx = cx + int(80 * math.cos(rad))
        ny = cy + int(80 * math.sin(rad))
        draw.line([(cx, cy), (nx, ny)], fill=(180, 20, 20), width=3)
        draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(30, 30, 30))
        draw.text((mx + 40, my + 118), label, fill=(30, 30, 30))
    
    # SECTION 3: Toggle Switch Bank & Status LEDs
    draw.rectangle([60, 660, 960, 960], fill=(25, 28, 32), outline=(45, 50, 56), width=4)
    draw.text((80, 680), "SHUTTER & CAPACITOR CONTROL BANK - MANUAL OVERRIDE", fill=(210, 175, 20))
    
    # LED Bank
    for row in range(3):
        for col in range(12):
            lx = 100 + col * 72
            ly = 730 + row * 65
            # LED
            c = (40, 220, 60) if (col + row) % 3 != 0 else (240, 40, 30)
            draw.ellipse([lx, ly, lx + 20, ly + 20], fill=c, outline=(10, 10, 10), width=2)
            # Switch toggle below LED
            draw.rectangle([lx + 6, ly + 28, lx + 14, ly + 48], fill=(180, 185, 190), outline=(10, 10, 10))
            draw.ellipse([lx + 4, ly + 24, lx + 16, ly + 36], fill=(210, 215, 220))
    
    img.save(os.path.join(TEX_DIR, "console_desk.png"))
    print("Saved console_desk.png")

gen_console_desk()
