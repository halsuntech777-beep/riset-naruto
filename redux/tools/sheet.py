import sys, os
from PIL import Image, ImageDraw
def conv(path, w=320, h=240):
    d = open(path, 'rb').read(); n = len(d)
    if n == w*h*2:
        im = Image.new('RGB', (w, h)); px = im.load()
        for i in range(w*h):
            v = d[2*i] | (d[2*i+1] << 8)
            px[i % w, i // w] = ((v & 31) << 3, ((v >> 5) & 31) << 3, ((v >> 10) & 31) << 3)
    elif n == w*h*3:
        im = Image.frombytes('RGB', (w, h), d)
    else:
        raise SystemExit(f"ukuran tak dikenal {n} untuk {path}")
    ImageDraw.Draw(im).text((4, 2), os.path.basename(path), fill=(255, 255, 0))
    return im
out, files = sys.argv[1], sys.argv[2:]
ims = [conv(f) for f in files]; cols = 4; rows = (len(ims) + cols - 1) // cols
sheet = Image.new('RGB', (320*cols, 240*rows))
for i, im in enumerate(ims): sheet.paste(im, ((i % cols)*320, (i // cols)*240))
sheet.save(out); print("ok", sheet.size)
