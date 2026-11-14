import os
import random
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

TEX_DIR = "/home/koundinyag/Projects/LH1/assets/textures"
os.makedirs(TEX_DIR, exist_ok=True)

def gen_floor():
    size = (512, 512)
    img = Image.new("RGB", size, (35, 38, 42))
    draw = ImageDraw.Draw(img)
    # Grid lines for observatory tiles
    for x in range(0, 512, 64):
        draw.line([(x, 0), (x, 512)], fill=(20, 22, 25), width=2)
    for y in range(0, 512, 64):
        draw.line([(0, y), (512, y)], fill=(20, 22, 25), width=2)
    # Noise speckles
    pixels = img.load()
    for x in range(512):
        for y in range(512):
            if random.random() < 0.2:
                v = random.randint(-15, 15)
                r, g, b = pixels[x, y]
                pixels[x, y] = (max(0, min(255, r + v)), max(0, min(255, g + v)), max(0, min(255, b + v)))
    img.save(os.path.join(TEX_DIR, "floor.png"))
    print("Saved floor.png")

def gen_wall():
    size = (512, 512)
    img = Image.new("RGB", size, (48, 52, 58))
    draw = ImageDraw.Draw(img)
    # Industrial panels
    draw.rectangle([10, 10, 502, 502], outline=(30, 32, 36), width=3)
    draw.line([(256, 10), (256, 502)], fill=(30, 32, 36), width=2)
    # Rivet dots
    for y in [24, 128, 256, 384, 488]:
        for x in [24, 256, 488]:
            draw.ellipse([x-4, y-4, x+4, y+4], fill=(70, 75, 82), outline=(25, 27, 30))
    # Scratch noise
    pixels = img.load()
    for x in range(512):
        for y in range(512):
            n = random.randint(-10, 10)
            r, g, b = pixels[x, y]
            pixels[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    img.save(os.path.join(TEX_DIR, "wall.png"))
    print("Saved wall.png")

def gen_mirror_glass():
    # Subtle silvery optical coating with hex grid pattern like James Webb / lunar retroreflector array
    size = (256, 256)
    img = Image.new("RGBA", size, (200, 240, 255, 240))
    draw = ImageDraw.Draw(img)
    # Hexagonal / prismatic reflector pattern
    step = 32
    for x in range(0, 256, step):
        draw.line([(x, 0), (x, 256)], fill=(240, 255, 255, 120), width=1)
        draw.line([(0, x), (256, x)], fill=(240, 255, 255, 120), width=1)
    # Specular rim
    draw.rectangle([0, 0, 255, 255], outline=(255, 255, 255, 255), width=4)
    img.save(os.path.join(TEX_DIR, "mirror_glass.png"))
    print("Saved mirror_glass.png")

def gen_polaroid():
    # A 1970s polaroid photo
    # Cream/white frame with square photo
    img = Image.new("RGB", (400, 480), (242, 238, 225))
    draw = ImageDraw.Draw(img)
    
    # Photo square
    photo_box = [30, 30, 370, 370]
    draw.rectangle(photo_box, fill=(15, 18, 22))
    
    # In the photo: An astronomer at a desk, looking at camera
    # Room lighting is dark reddish amber
    draw.rectangle([40, 40, 360, 360], fill=(25, 18, 15))
    
    # Observatory console in background
    draw.rectangle([60, 220, 340, 350], fill=(40, 45, 50))
    # Oscilloscope screen (green glow)
    draw.ellipse([80, 240, 140, 300], fill=(0, 40, 10), outline=(0, 255, 80), width=2)
    # Waveform
    draw.line([(85, 270), (100, 255), (115, 285), (135, 270)], fill=(50, 255, 120), width=2)
    
    # Wall mirror in background:
    draw.rectangle([200, 80, 320, 220], fill=(12, 14, 20), outline=(120, 130, 140), width=3)
    
    # IN THE MIRROR: Tall faceless pitch-black silhouette looming directly behind
    # Entity silhouette in the mirror:
    draw.ellipse([245, 95, 275, 130], fill=(0, 0, 0)) # head
    draw.rectangle([240, 130, 280, 215], fill=(0, 0, 0)) # body
    # Eerie faint void glow around entity
    draw.ellipse([243, 93, 277, 132], outline=(120, 0, 40), width=1)
    
    # In front of mirror (foreground): Astronomer sitting at desk (back half turned)
    # Astronomer head
    draw.ellipse([140, 150, 190, 210], fill=(160, 130, 100)) # head
    draw.rectangle([120, 200, 210, 320], fill=(80, 90, 110)) # lab coat / sweater
    # Glasses
    draw.line([(155, 175), (185, 175)], fill=(20, 20, 20), width=2)
    
    # Polaroid bottom text handwritten style
    try:
        # Draw handwritten text
        draw.text((40, 390), "MOUNT HALE OBSERVATORY - OCT 14, 1978", fill=(50, 40, 30))
        draw.text((40, 415), "TEST #4: PERSEUS CALIBRATION", fill=(60, 40, 30))
        draw.text((40, 440), "WHAT IS IN THE MIRROR?!", fill=(180, 20, 20))
    except Exception:
        pass
    
    # Add photographic film grain & vintage color tone
    img = img.filter(ImageFilter.SMOOTH_MORE)
    img.save(os.path.join(TEX_DIR, "polaroid.png"))
    print("Saved polaroid.png")

def gen_laser_housing():
    # Vintage 1970s scientific instrument texture (hazard stripes + brushed steel)
    img = Image.new("RGB", (256, 256), (30, 30, 35))
    draw = ImageDraw.Draw(img)
    # Yellow hazard stripes
    stripe_w = 24
    for i in range(-256, 512, stripe_w * 2):
        draw.polygon([(i, 0), (i + stripe_w, 0), (i + stripe_w + 100, 256), (i + 100, 256)], fill=(220, 170, 20))
    # Metal plates overlay
    draw.rectangle([20, 40, 236, 120], fill=(45, 50, 55), outline=(15, 15, 18), width=3)
    draw.rectangle([30, 50, 100, 110], fill=(10, 12, 14)) # LED gauge area
    draw.rectangle([120, 60, 220, 100], fill=(80, 85, 90)) # Label plate
    img.save(os.path.join(TEX_DIR, "laser_casing.png"))
    print("Saved laser_casing.png")

gen_floor()
gen_wall()
gen_mirror_glass()
gen_polaroid()
gen_laser_housing()
print("Texture generation complete!")
