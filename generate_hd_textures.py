import os
import random
import math
from PIL import Image, ImageDraw, ImageFilter

TEX_DIR = "/home/koundinyag/Projects/LH1/assets/textures"
os.makedirs(TEX_DIR, exist_ok=True)

def gen_hd_floor():
    size = (1024, 1024)
    img = Image.new("RGB", size, (28, 30, 34))
    draw = ImageDraw.Draw(img)
    
    # 4x4 big tiles (256x256 each)
    tile_size = 256
    for tx in range(0, 1024, tile_size):
        for ty in range(0, 1024, tile_size):
            # Tile variation
            base_v = random.randint(-4, 4)
            t_col = (32 + base_v, 35 + base_v, 40 + base_v)
            draw.rectangle([tx + 4, ty + 4, tx + tile_size - 4, ty + tile_size - 4], fill=t_col)
            
            # Subtle inner border
            draw.rectangle([tx + 6, ty + 6, tx + tile_size - 6, ty + tile_size - 6], outline=(22, 24, 28), width=1)
            
            # Corner rivets on metal tiles
            for rx in [tx + 16, tx + tile_size - 16]:
                for ry in [ty + 16, ty + tile_size - 16]:
                    draw.ellipse([rx - 3, ry - 3, rx + 3, ry + 3], fill=(60, 65, 72), outline=(15, 17, 20))
            
            # Thin alignment grid markings on observatory tiles
            cx = tx + tile_size // 2
            cy = ty + tile_size // 2
            draw.line([(cx - 10, cy), (cx + 10, cy)], fill=(50, 55, 62), width=1)
            draw.line([(cx, cy - 10), (cx, cy + 10)], fill=(50, 55, 62), width=1)
    
    # Recessed dark grout lines
    for x in range(0, 1025, tile_size):
        draw.line([(x, 0), (x, 1024)], fill=(12, 13, 15), width=6)
        draw.line([(x-1, 0), (x-1, 1024)], fill=(55, 60, 68), width=1)
    for y in range(0, 1025, tile_size):
        draw.line([(0, y), (1024, y)], fill=(12, 13, 15), width=6)
        draw.line([(0, y-1), (1024, y-1)], fill=(55, 60, 68), width=1)
    
    # Noise and scuffs
    pixels = img.load()
    for x in range(1024):
        for y in range(1024):
            if random.random() < 0.25:
                n = random.randint(-12, 12)
                r, g, b = pixels[x, y]
                pixels[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    
    img = img.filter(ImageFilter.SMOOTH)
    img.save(os.path.join(TEX_DIR, "floor.png"))
    print("Saved HD floor.png")

def gen_hd_wall():
    size = (1024, 1024)
    # Industrial painted steel panel (dark olive-slate)
    img = Image.new("RGB", size, (42, 46, 50))
    draw = ImageDraw.Draw(img)
    
    # Two horizontal structural girder sections
    draw.rectangle([0, 0, 1024, 80], fill=(30, 33, 37))
    draw.rectangle([0, 944, 1024, 1024], fill=(30, 33, 37))
    
    # Rivet lines along top and bottom girders
    for x in range(32, 1024, 64):
        draw.ellipse([x-5, 35, x+5, 45], fill=(75, 80, 88), outline=(15, 17, 20), width=2)
        draw.ellipse([x-5, 975, x+5, 985], fill=(75, 80, 88), outline=(15, 17, 20), width=2)
    
    # Vertical panel seams (4 panels across)
    for px in [256, 512, 768]:
        draw.line([(px, 80), (px, 944)], fill=(18, 20, 24), width=6)
        draw.line([(px-1, 80), (px-1, 944)], fill=(70, 75, 85), width=1)
        # Seam bolts
        for by in range(120, 920, 100):
            draw.ellipse([px-4, by-4, px+4, by+4], fill=(65, 70, 78), outline=(15, 17, 20))
    
    # Yellow / Black hazard warning bar along middle-bottom
    hy = 850
    draw.rectangle([0, hy, 1024, hy + 36], fill=(25, 27, 30))
    for i in range(-50, 1050, 48):
        draw.polygon([(i, hy), (i + 24, hy), (i + 48, hy + 36), (i + 24, hy + 36)], fill=(210, 165, 20))
    
    # Vent louvers on panel 2 (from 280 to 480)
    vy_start = 200
    for i in range(12):
        y = vy_start + i * 28
        draw.rectangle([290, y, 480, y + 14], fill=(15, 16, 18), outline=(25, 27, 30))
        draw.line([(290, y + 14), (480, y + 14)], fill=(75, 80, 88), width=1)
    
    # 1970s Stencil Text
    draw.rectangle([540, 240, 740, 320], fill=(28, 30, 34), outline=(15, 16, 18), width=2)
    draw.text((550, 252), "MT. HALE OBSERVATORY", fill=(200, 205, 215))
    draw.text((550, 274), "SEC-4: OPTICS CORRIDOR", fill=(180, 185, 195))
    draw.text((550, 296), "HIGH VOLTAGE LASER FACILITY", fill=(210, 160, 20))
    
    # Subtle metal scratches
    pixels = img.load()
    for x in range(1024):
        for y in range(1024):
            if random.random() < 0.2:
                n = random.randint(-10, 10)
                r, g, b = pixels[x, y]
                pixels[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    
    img.save(os.path.join(TEX_DIR, "wall.png"))
    print("Saved HD wall.png")

def gen_hd_mirror_glass():
    # 512x512 Lunar Retroreflector Corner-Cube Hexagonal Array
    size = (512, 512)
    img = Image.new("RGBA", size, (215, 245, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Hexagonal retroreflector array pattern
    hex_r = 32
    h_w = hex_r * math.sqrt(3)
    h_h = hex_r * 2
    
    for row in range(-1, 14):
        for col in range(-1, 14):
            cx = col * h_w + (h_w / 2 if row % 2 == 1 else 0)
            cy = row * (h_h * 0.75)
            
            # Draw hexagon
            points = []
            for a in range(6):
                angle = math.radians(a * 60 + 30)
                px = cx + hex_r * math.cos(angle)
                py = cy + hex_r * math.sin(angle)
                points.append((px, py))
            
            # Prismatic facets (corner cube retroreflector interior triangle lines)
            draw.polygon(points, fill=(225, 245, 255, 240), outline=(160, 210, 235, 255))
            for p in [points[0], points[2], points[4]]:
                draw.line([(cx, cy), p], fill=(170, 220, 245, 200), width=1)
            for p in [points[1], points[3], points[5]]:
                draw.line([(cx, cy), p], fill=(245, 255, 255, 255), width=1)
    
    # Outer polished chrome bevel
    draw.rectangle([0, 0, 511, 511], outline=(255, 255, 255, 255), width=8)
    draw.rectangle([8, 8, 503, 503], outline=(140, 180, 200, 255), width=4)
    img.save(os.path.join(TEX_DIR, "mirror_glass.png"))
    print("Saved HD mirror_glass.png")

def gen_hd_polaroid():
    # High-resolution authentic 1970s Polaroid
    w, h = 900, 1080
    img = Image.new("RGB", (w, h), (238, 232, 218)) # Authentic creamy Polaroid border
    draw = ImageDraw.Draw(img)
    
    # Vintage photo print square (top centered)
    px0, py0, px1, py1 = 65, 65, 835, 835
    draw.rectangle([px0, py0, px1, py1], fill=(16, 14, 18))
    
    # Observatory control room interior in photo:
    # Dim reddish amber ambient lighting
    draw.rectangle([px0+4, py0+4, px1-4, py1-4], fill=(22, 18, 20))
    
    # Control console desks in background
    draw.rectangle([px0+20, 450, px1-20, 800], fill=(35, 38, 44))
    
    # Oscilloscope screen (green glow)
    draw.ellipse([140, 490, 280, 630], fill=(5, 30, 10), outline=(30, 220, 80), width=4)
    # Sine wave on scope
    wave_pts = []
    for x in range(150, 270):
        y = 560 + int(24 * math.sin((x - 150) * 0.1))
        wave_pts.append((x, y))
    draw.line(wave_pts, fill=(50, 255, 120), width=3)
    
    # Dial meters
    for dx in [320, 400, 480]:
        draw.rectangle([dx, 510, dx+60, 570], fill=(240, 235, 220), outline=(10, 10, 10), width=2)
        draw.line([(dx+30, 560), (dx+45, 525)], fill=(180, 20, 20), width=2)
    
    # Large Wall Mirror in background:
    mx0, my0, mx1, my1 = 520, 120, 810, 540
    draw.rectangle([mx0, my0, mx1, my1], fill=(12, 16, 24), outline=(160, 175, 190), width=6)
    
    # IN THE MIRROR: Chilling, tall, pitch-black faceless shadow entity standing directly behind!
    # Shadow silhouette:
    ex = 665
    draw.ellipse([ex - 35, 170, ex + 35, 255], fill=(0, 0, 0)) # head
    draw.polygon([(ex - 50, 255), (ex + 50, 255), (ex + 70, 530), (ex - 70, 530)], fill=(0, 0, 0)) # torso
    # Long eerie arms
    draw.line([(ex - 50, 260), (ex - 90, 420)], fill=(0, 0, 0), width=18)
    draw.line([(ex + 50, 260), (ex + 90, 420)], fill=(0, 0, 0), width=18)
    # Void distortion aura around entity
    draw.ellipse([ex - 42, 163, ex + 42, 262], outline=(180, 0, 40), width=2)
    draw.ellipse([ex - 46, 159, ex + 46, 266], outline=(90, 0, 20), width=1)
    
    # Foreground: The Astronomer at his desk (head & shoulders)
    # He is smiling at camera, completely unaware of what is in the mirror behind him!
    ax = 360
    draw.ellipse([ax - 65, 270, ax + 65, 410], fill=(195, 155, 120)) # head
    # Hair
    draw.ellipse([ax - 70, 250, ax + 70, 310], fill=(60, 45, 30))
    # Glasses
    draw.rectangle([ax - 45, 320, ax - 10, 350], outline=(20, 20, 20), width=3)
    draw.rectangle([ax + 10, 320, ax + 45, 350], outline=(20, 20, 20), width=3)
    draw.line([(ax - 10, 335), (ax + 10, 335)], fill=(20, 20, 20), width=3)
    # Smile
    draw.arc([ax - 20, 360, ax + 20, 385], 0, 180, fill=(120, 40, 40), width=3)
    # Lab coat collar
    draw.polygon([(ax - 90, 410), (ax + 90, 410), (ax + 140, 750), (ax - 140, 750)], fill=(215, 220, 225))
    draw.line([(ax, 410), (ax, 750)], fill=(160, 165, 175), width=3)
    
    # Polaroid bottom handwritten text in authentic vintage ink style
    draw.text((80, 875), "MOUNT HALE LUNAR OBSERVATORY", fill=(35, 30, 28))
    draw.text((80, 915), "TEST #77-B: PERSEUS VOID CALIBRATION - OCT 14, 1978", fill=(55, 45, 40))
    draw.text((80, 960), "LOOK IN THE MIRROR. IT FOLLOWED THE BEAM BACK DOWN.", fill=(190, 20, 20))
    draw.text((80, 1005), "DIRECT LIGHT DOES NOTHING. REFLECT THE BEAM TO BANISH IT.", fill=(160, 30, 30))
    
    # Aging vignette & grain
    img = img.filter(ImageFilter.SMOOTH)
    img.save(os.path.join(TEX_DIR, "polaroid.png"))
    print("Saved HD polaroid.png")

def gen_hd_laser_casing():
    # 1024x1024 Handheld Laser Emitter Texture
    size = (1024, 1024)
    img = Image.new("RGB", size, (35, 38, 42))
    draw = ImageDraw.Draw(img)
    
    # Heavy diagonal yellow/black hazard stripes across upper half
    stripe_w = 48
    for i in range(-1024, 2048, stripe_w * 2):
        draw.polygon([(i, 0), (i + stripe_w, 0), (i + stripe_w + 400, 512), (i + 400, 512)], fill=(230, 180, 15))
        draw.polygon([(i + stripe_w, 0), (i + stripe_w * 2, 0), (i + stripe_w * 2 + 400, 512), (i + stripe_w + 400, 512)], fill=(20, 22, 25))
    
    # Metal reinforcement plates
    draw.rectangle([40, 530, 984, 984], fill=(50, 55, 62), outline=(20, 22, 25), width=6)
    
    # Emitter Heat Status Window
    draw.rectangle([80, 570, 500, 720], fill=(12, 14, 16), outline=(30, 35, 40), width=4)
    draw.text((100, 590), "OPTICAL HEAT DISSIPATION", fill=(210, 170, 20))
    # LED heat gauge bar slots
    for i in range(12):
        col = (40, 220, 80) if i < 7 else ((240, 190, 20) if i < 10 else (240, 40, 30))
        draw.rectangle([100 + i * 30, 630, 122 + i * 30, 680], fill=col)
    
    # Specification Plate
    draw.rectangle([540, 570, 940, 720], fill=(200, 205, 210), outline=(20, 22, 25), width=3)
    draw.text((560, 590), "MODEL 74 CALIBRATION EMITTER", fill=(10, 10, 10))
    draw.text((560, 620), "WAVELENGTH: 488 nm (HIGH PULSE)", fill=(20, 20, 20))
    draw.text((560, 650), "CAUTION: OVERHEAT LOCKOUT ACTIVE", fill=(180, 10, 10))
    draw.text((560, 680), "PROPERTY OF MT. HALE OBSERVATORY", fill=(30, 30, 30))
    
    # Heat sink louvers
    for i in range(10):
        y = 760 + i * 20
        draw.rectangle([80, y, 940, y + 10], fill=(20, 22, 25))
    
    img.save(os.path.join(TEX_DIR, "laser_casing.png"))
    print("Saved HD laser_casing.png")

gen_hd_floor()
gen_hd_wall()
gen_hd_mirror_glass()
gen_hd_polaroid()
gen_hd_laser_casing()
print("All HD textures generated!")
