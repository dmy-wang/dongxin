#!/usr/bin/env python3
"""生成 薪速 应用图标（1024x1024 PNG -> iconset -> icns），纯标准库。"""
import zlib, struct, math, os, subprocess

S = 1024          # 输出尺寸
SS = 3            # 超采样倍数
N = S * SS

def lerp(a, b, t): return a + (b - a) * t

def bg_color(x, y):
    # 深蓝紫 -> 暖金 的对角渐变
    t = (x / N * 0.45 + (1 - y / N) * 0.55)
    c1 = (0.075, 0.08, 0.13)
    c2 = (0.98, 0.63, 0.16)
    r = lerp(c1[0], c2[0], t ** 1.6)
    g = lerp(c1[1], c2[1], t ** 1.6)
    b = lerp(c1[2], c2[2], t ** 1.6)
    return r, g, b

def in_rounded_rect(x, y, x0, y0, x1, y1, r):
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r and x0 <= x <= x1 and y0 <= y <= y1

def yen_mask(x, y):
    """返回 0..1 的 ¥ 覆盖率（几何构造）"""
    cx = N / 2
    top = N * 0.28
    bottom = N * 0.76
    w = N * 0.052          # 笔画半宽
    # 两条斜线（从顶点到中部）
    mid = N * 0.52
    hit = 0.0
    for sx in (-1, 1):
        x1, y1 = cx, top
        x2, y2 = cx + sx * N * 0.145, mid
        # 点到线段距离
        dx, dy = x2 - x1, y2 - y1
        L2 = dx * dx + dy * dy
        t = ((x - x1) * dx + (y - y1) * dy) / L2
        if 0 <= t <= 1:
            px, py = x1 + t * dx, y1 + t * dy
            d = math.hypot(x - px, y - py)
            hit = max(hit, max(0.0, min(1.0, (w - d) / (SS * 1.2))))
    # 竖线（中部到底）
    if abs(x - cx) <= w and mid - w * 0.5 <= y <= bottom:
        hit = max(hit, 1.0)
    # 两条横杠
    for yy in (N * 0.60, N * 0.70):
        if abs(y - yy) <= w * 0.82 and cx - N * 0.145 <= x <= cx + N * 0.145:
            hit = max(hit, 1.0)
    return hit

def render():
    px = bytearray(N * N * 4)
    margin = N * 0.055
    r = N * 0.22
    x0, y0, x1, y1 = margin, margin, N - margin, N - margin
    for y in range(N):
        for x in range(N):
            i = (y * N + x) * 4
            if not in_rounded_rect(x, y, x0, y0, x1, y1, r):
                px[i:i+4] = b'\x00\x00\x00\x00'
                continue
            br, bg, bb = bg_color(x, y)
            # 右上角高光
            d = math.hypot(x - x1 * 0.78, y - y0 * 1.25)
            hl = max(0.0, 1 - d / (N * 0.55)) * 0.22
            br, bg, bb = br + hl, bg + hl, bb + hl
            m = yen_mask(x, y)
            # ¥ 颜色：白 -> 深琥珀
            fr, fg, fb = 1.0, 0.98, 0.92
            dr, dg, db = 0.22, 0.12, 0.03
            tt = m
            rr = lerp(br, lerp(dr, fr, tt), 0.95 * m + 0.05)
            gg = lerp(bg, lerp(dg, fg, tt), 0.95 * m + 0.05)
            bbb = lerp(bb, lerp(db, fb, tt), 0.95 * m + 0.05)
            if m > 0.02:
                # 白色描边层
                rr = lerp(rr, 1.0, 0.55 * min(1.0, m))
                gg = lerp(gg, 0.98, 0.55 * min(1.0, m))
                bbb = lerp(bbb, 0.92, 0.55 * min(1.0, m))
            px[i] = int(max(0, min(1, rr)) * 255)
            px[i+1] = int(max(0, min(1, gg)) * 255)
            px[i+2] = int(max(0, min(1, bbb)) * 255)
            px[i+3] = 255
    # 下采样 SSxSS
    out = bytearray(S * S * 4)
    for y in range(S):
        for x in range(S):
            r_ = g_ = b_ = a_ = 0
            for dy in range(SS):
                for dx in range(SS):
                    j = ((y * SS + dy) * N + (x * SS + dx)) * 4
                    r_ += px[j]; g_ += px[j+1]; b_ += px[j+2]; a_ += px[j+3]
            n = SS * SS
            o = (y * S + x) * 4
            out[o] = r_ // n; out[o+1] = g_ // n; out[o+2] = b_ // n; out[o+3] = a_ // n
    return out

def write_png(path, data, w, h):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += data[y * w * 4:(y + 1) * w * 4]
    def chunk(tag, payload):
        c = struct.pack('>I', len(payload)) + tag + payload
        return c + struct.pack('>I', zlib.crc32(tag + payload) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)

if __name__ == '__main__':
    os.makedirs('assets', exist_ok=True)
    data = render()
    write_png('assets/icon_1024.png', data, S, S)
    # iconset
    iset = 'assets/AppIcon.iconset'
    subprocess.run(['rm', '-rf', iset])
    os.makedirs(iset, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        for scale, suffix in ((1, ''), (2, '@2x')):
            size = base * scale
            # 用 sips 缩放
            src = 'assets/icon_1024.png'
            dst = f'{iset}/icon_{base}x{base}{suffix}.png'
            subprocess.run(['sips', '-z', str(size), str(size), src, '--out', dst],
                           check=True, capture_output=True)
    with open(f'{iset}/icon_1024x1024@2x.png', 'wb') as f:
        f.write(open('assets/icon_1024.png', 'rb').read())
    print('iconset ready')
