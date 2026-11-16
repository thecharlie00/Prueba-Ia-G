"""Genera las portadas de los juegos de Tablerama (SVG -> PNG 512x640).
Estilo: arcilla cartoon, contorno tinta, fondo con degradado y patrón suave, sin texto."""
import math, subprocess, sys, os

OUT = sys.argv[1]
INK = "#1d1a3a"
PAPER = "#fdf6e9"
W, H = 400, 500
SW = 7  # grosor de contorno

def svg(body, bg_top, bg_bot, pattern=""):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{bg_top}"/><stop offset="1" stop-color="{bg_bot}"/></linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.42" r="0.55"><stop offset="0" stop-color="#ffffff" stop-opacity="0.38"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient>
  <clipPath id="card"><rect x="10" y="10" width="{W-20}" height="{H-20}" rx="34"/></clipPath>
</defs>
<g clip-path="url(#card)">
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  {pattern}
  <rect width="{W}" height="{H}" fill="url(#glow)"/>
  <ellipse cx="200" cy="430" rx="150" ry="26" fill="{INK}" opacity="0.18"/>
  {body}
</g>
<rect x="10" y="10" width="{W-20}" height="{H-20}" rx="34" fill="none" stroke="{INK}" stroke-width="10"/>
<rect x="22" y="22" width="{W-44}" height="{H-44}" rx="25" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="3"/>
</svg>'''

def dots(color, step=34, r=4, op=0.18):
    out = []
    for j in range(0, H + step, step):
        for i in range(0, W + step, step):
            x = i + (step / 2 if (j // step) % 2 else 0)
            out.append(f'<circle cx="{x}" cy="{j}" r="{r}" fill="{color}" opacity="{op}"/>')
    return "".join(out)

def stripes(color, op=0.12, step=36, angle=-25):
    out = [f'<g transform="rotate({angle} 200 250)" opacity="{op}">']
    for i in range(-400, 800, step):
        out.append(f'<rect x="{i}" y="-300" width="{step/2}" height="1100" fill="{color}"/>')
    out.append("</g>")
    return "".join(out)

def sparkle(x, y, s=1.0, color=PAPER):
    p = f"M{x},{y-14*s} Q{x+2*s},{y-2*s} {x+14*s},{y} Q{x+2*s},{y+2*s} {x},{y+14*s} Q{x-2*s},{y+2*s} {x-14*s},{y} Q{x-2*s},{y-2*s} {x},{y-14*s}Z"
    return f'<path d="{p}" fill="{color}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>'

def die(x, y, size, rot, face=5, body=PAPER, pip=INK):
    s = size
    pips = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
            4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
            6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}[face]
    g = [f'<g transform="translate({x} {y}) rotate({rot})">',
         f'<rect x="{-s/2+5}" y="{-s/2+9}" width="{s}" height="{s}" rx="{s*0.22}" fill="{INK}" opacity="0.25"/>',
         f'<rect x="{-s/2}" y="{-s/2}" width="{s}" height="{s}" rx="{s*0.22}" fill="{body}" stroke="{INK}" stroke-width="{SW}"/>',
         f'<rect x="{-s/2+s*0.12}" y="{-s/2+s*0.1}" width="{s*0.45}" height="{s*0.14}" rx="{s*0.07}" fill="#ffffff" opacity="0.7"/>']
    for px, py in pips:
        g.append(f'<circle cx="{px*s*0.27}" cy="{py*s*0.27}" r="{s*0.085}" fill="{pip}"/>')
    g.append("</g>")
    return "".join(g)

def token(x, y, color, scale=1.0):
    """Ficha de parchís/ludo: peón cónico con cabeza redonda."""
    s = scale
    dark = shade(color, 0.75)
    return (f'<g transform="translate({x} {y}) scale({s})">'
            f'<ellipse cx="4" cy="62" rx="40" ry="12" fill="{INK}" opacity="0.25"/>'
            f'<path d="M-34,58 Q-36,40 -14,30 L-10,-4 L10,-4 L14,30 Q36,40 34,58 Z" fill="{color}" stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round"/>'
            f'<path d="M-30,52 Q0,64 30,52" fill="none" stroke="{dark}" stroke-width="5" stroke-linecap="round"/>'
            f'<circle cx="0" cy="-18" r="20" fill="{color}" stroke="{INK}" stroke-width="{SW}"/>'
            f'<ellipse cx="-7" cy="-25" rx="7" ry="5" fill="#ffffff" opacity="0.7"/>'
            f'</g>')

def chip(x, y, color, r=30, h=12):
    dark = shade(color, 0.72)
    return (f'<g transform="translate({x} {y})">'
            f'<ellipse cx="0" cy="{h}" rx="{r}" ry="{r*0.45}" fill="{dark}" stroke="{INK}" stroke-width="{SW-1}"/>'
            f'<rect x="{-r}" y="0" width="{2*r}" height="{h}" fill="{dark}"/>'
            f'<line x1="{-r}" y1="0" x2="{-r}" y2="{h}" stroke="{INK}" stroke-width="{SW-1}"/><line x1="{r}" y1="0" x2="{r}" y2="{h}" stroke="{INK}" stroke-width="{SW-1}"/>'
            f'<ellipse cx="0" cy="0" rx="{r}" ry="{r*0.45}" fill="{color}" stroke="{INK}" stroke-width="{SW-1}"/>'
            f'<ellipse cx="0" cy="0" rx="{r*0.6}" ry="{r*0.26}" fill="none" stroke="#ffffff" stroke-opacity="0.55" stroke-width="3"/>'
            f'</g>')

def shade(hexcolor, k):
    h = hexcolor.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % (int(r*k), int(g*k), int(b*k))

def card(x, y, rot, face_svg, w=120, h=170, color=PAPER):
    return (f'<g transform="translate({x} {y}) rotate({rot})">'
            f'<rect x="{-w/2+6}" y="{-h/2+10}" width="{w}" height="{h}" rx="14" fill="{INK}" opacity="0.22"/>'
            f'<rect x="{-w/2}" y="{-h/2}" width="{w}" height="{h}" rx="14" fill="{color}" stroke="{INK}" stroke-width="{SW-1}"/>'
            f'<rect x="{-w/2+9}" y="{-h/2+9}" width="{w-18}" height="{h-18}" rx="9" fill="none" stroke="{INK}" stroke-opacity="0.18" stroke-width="3"/>'
            f'{face_svg}</g>')

def hexagon(cx, cy, r, fill, extra=""):
    pts = " ".join(f"{cx + r*math.cos(math.radians(60*i+30)):.1f},{cy + r*0.78*math.sin(math.radians(60*i+30)):.1f}" for i in range(6))
    return f'<polygon points="{pts}" fill="{fill}" stroke="{INK}" stroke-width="{SW-1}" stroke-linejoin="round"/>{extra}'

RED, BLUE, YEL, GRN = "#ff5d55", "#4fa3ff", "#ffc83d", "#3fcf8e"

covers = {}

# 1. Parchís: tablero en cruz inclinado, casas de colores, dado y fichas.
board = ['<g transform="translate(200 245) rotate(-12) skewX(4)">',
         f'<rect x="-150" y="-150" width="300" height="300" rx="26" fill="{PAPER}" stroke="{INK}" stroke-width="{SW}"/>']
for (cx, cy, col) in [(-95, -95, RED), (95, -95, BLUE), (-95, 95, GRN), (95, 95, YEL)]:
    board.append(f'<rect x="{cx-48}" y="{cy-48}" width="96" height="96" rx="18" fill="{col}" stroke="{INK}" stroke-width="5"/>')
    board.append(f'<circle cx="{cx}" cy="{cy}" r="26" fill="{PAPER}" stroke="{INK}" stroke-width="4" opacity="0.9"/>')
for i in range(-2, 3):
    board.append(f'<line x1="-46" y1="{i*18}" x2="46" y2="{i*18}" stroke="{INK}" stroke-opacity="0.25" stroke-width="3"/>')
    board.append(f'<line x1="{i*18}" y1="-140" x2="{i*18}" y2="140" stroke="{INK}" stroke-opacity="0.12" stroke-width="3"/>')
board.append(f'<polygon points="-46,-46 46,-46 0,0" fill="{BLUE}" stroke="{INK}" stroke-width="4"/>'
             f'<polygon points="46,-46 46,46 0,0" fill="{YEL}" stroke="{INK}" stroke-width="4"/>'
             f'<polygon points="46,46 -46,46 0,0" fill="{GRN}" stroke="{INK}" stroke-width="4"/>'
             f'<polygon points="-46,46 -46,-46 0,0" fill="{RED}" stroke="{INK}" stroke-width="4"/>')
board.append("</g>")
covers["parchis"] = svg("".join(board) + token(120, 320, RED, 1.1) + token(300, 160, GRN, 0.9) + die(280, 360, 92, 18, 5)
                        + sparkle(70, 80, 1.2) + sparkle(340, 70, 0.8),
                        "#ff8a70", "#d8433f", dots("#ffffff", 30, 4, 0.16))

# 2. Ludo: camino serpenteante y ficha gigante.
path = []
for i in range(9):
    x = 60 + i * 36
    y = 330 + 40 * math.sin(i * 0.8)
    col = [RED, BLUE, YEL, GRN][i % 4] if i % 2 == 0 else PAPER
    path.append(f'<rect x="{x-18}" y="{y-18}" width="36" height="36" rx="8" fill="{col}" stroke="{INK}" stroke-width="5" transform="rotate({i*7-20} {x} {y})"/>')
covers["ludo"] = svg("".join(path) + token(200, 200, YEL, 2.0) + die(310, 120, 70, -14, 6) + chip(90, 150, BLUE, 26, 10)
                     + sparkle(80, 70, 1.0) + sparkle(330, 250, 0.9),
                     "#ffb35a", "#f07c1f", stripes("#ffffff", 0.13))

# 3. Brisca: abanico de cartas españolas.
def coin(): return f'<circle cx="0" cy="0" r="30" fill="{YEL}" stroke="{INK}" stroke-width="5"/><circle cx="0" cy="0" r="14" fill="none" stroke="{INK}" stroke-width="4"/>'
def cup(): return (f'<path d="M-26,-30 L26,-30 Q24,8 6,14 L6,30 L20,36 L-20,36 L-6,30 L-6,14 Q-24,8 -26,-30Z" fill="{RED}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
def sword(): return (f'<g transform="rotate(30)"><rect x="-7" y="-52" width="14" height="78" rx="6" fill="#b9c6e8" stroke="{INK}" stroke-width="5"/>'
                     f'<rect x="-26" y="22" width="52" height="12" rx="6" fill="{YEL}" stroke="{INK}" stroke-width="5"/><rect x="-6" y="34" width="12" height="22" rx="5" fill="#a0522d" stroke="{INK}" stroke-width="5"/></g>')
def club(): return (f'<g transform="rotate(-25)"><path d="M-12,48 L-18,-30 Q-20,-52 0,-54 Q20,-52 18,-30 L12,48 Z" fill="#3fa36a" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
                    f'<circle cx="-8" cy="-20" r="5" fill="{INK}" opacity="0.35"/><circle cx="7" cy="2" r="5" fill="{INK}" opacity="0.35"/></g>')
fan = "".join(card(200 + (i - 1.5) * 62, 250 + abs(i - 1.5) * 18, (i - 1.5) * 18,
                   f'<g transform="translate(-30 -50) scale(0.62)">{f}</g><g transform="translate(30 50) rotate(180) scale(0.62)">{f}</g>', 130, 190)
              for i, f in enumerate([club(), sword(), cup(), coin()]))
covers["brisca"] = svg(fan + chip(80, 400, YEL, 30, 12) + chip(118, 418, YEL, 30, 12) + sparkle(330, 90, 1.3) + sparkle(70, 110, 0.8),
                       "#ffd36a", "#d99a00", dots("#ffffff", 34, 5, 0.2))

# 4. Ajedrez: caballo y rey en suelo de cuadros en perspectiva.
floor = ['<g transform="translate(200 345) scale(1 0.5) rotate(45)">']
for r in range(-4, 4):
    for c in range(-4, 4):
        col = "#efe6ff" if (r + c) % 2 == 0 else "#6b5fc0"
        floor.append(f'<rect x="{c*36}" y="{r*36}" width="36" height="36" fill="{col}" stroke="{INK}" stroke-width="3"/>')
floor.append("</g>")
knight = (f'<g transform="translate(150 190)"><path d="M-50,110 L50,110 L44,80 L36,78 Q40,20 20,-10 Q34,-30 30,-60 Q12,-70 -10,-56 Q-50,-40 -56,0 Q-44,10 -30,4 Q-24,24 -40,50 Q-48,70 -44,80 L-50,82 Z" '
          f'fill="{PAPER}" stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round"/><circle cx="4" cy="-34" r="6" fill="{INK}"/>'
          f'<path d="M-6,-62 Q4,-80 18,-70" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/></g>')
king = (f'<g transform="translate(270 160)"><rect x="-48" y="118" width="96" height="22" rx="10" fill="#4a3f9a" stroke="{INK}" stroke-width="{SW}"/>'
        f'<path d="M-36,118 Q-30,40 -20,10 L20,10 Q30,40 36,118 Z" fill="#5a4fb0" stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round"/>'
        f'<rect x="-30" y="-6" width="60" height="20" rx="9" fill="#5a4fb0" stroke="{INK}" stroke-width="{SW}"/>'
        f'<circle cx="0" cy="-26" r="22" fill="#5a4fb0" stroke="{INK}" stroke-width="{SW}"/>'
        f'<rect x="-6" y="-74" width="12" height="34" rx="4" fill="{YEL}" stroke="{INK}" stroke-width="5"/><rect x="-17" y="-64" width="34" height="12" rx="4" fill="{YEL}" stroke="{INK}" stroke-width="5"/>'
        f'<ellipse cx="-12" cy="40" rx="6" ry="24" fill="#ffffff" opacity="0.25"/></g>')
covers["chess"] = svg("".join(floor) + king + knight + sparkle(80, 80, 1.1) + sparkle(330, 60, 0.8),
                      "#a99cf0", "#5446a8", stripes("#ffffff", 0.08, 40, 20))

# 5. Damas: pila coronada sobre tablero.
grid = ['<g transform="translate(200 330) scale(1 0.5) rotate(45)">']
for r in range(-3, 3):
    for c in range(-3, 3):
        col = "#2a8f60" if (r + c) % 2 else "#c8f2dc"
        grid.append(f'<rect x="{c*44}" y="{r*44}" width="44" height="44" fill="{col}" stroke="{INK}" stroke-width="4"/>')
grid.append("</g>")
stack = "".join(chip(200, 230 - i * 22, RED if i < 3 else RED, 58, 22) for i in range(3))
crown = (f'<path d="M160,150 L170,110 L188,135 L200,100 L212,135 L230,110 L240,150 Z" fill="{YEL}" stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round"/>'
         f'<circle cx="200" cy="100" r="7" fill="{PAPER}" stroke="{INK}" stroke-width="4"/>')
covers["checkers"] = svg("".join(grid) + chip(95, 300, INK, 40, 16).replace(f'fill="{INK}"', 'fill="#3a3560"', 1) + chip(312, 330, RED, 40, 16)
                         + stack + crown + sparkle(70, 80, 1.1) + sparkle(330, 90, 1.0),
                         "#6fe0a8", "#1f9a62", dots("#ffffff", 30, 4, 0.16))

# 6. Dominó: fichas cayendo en cadena.
def tile(x, y, rot, a, b):
    pips = {0: [], 1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
            5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)], 6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}
    g = [f'<g transform="translate({x} {y}) rotate({rot})">',
         f'<rect x="-31" y="-58" width="70" height="128" rx="14" fill="{INK}" opacity="0.25"/>',
         f'<rect x="-36" y="-66" width="72" height="132" rx="14" fill="{PAPER}" stroke="{INK}" stroke-width="{SW}"/>',
         f'<line x1="-26" y1="0" x2="26" y2="0" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>']
    for (v, oy) in [(a, -33), (b, 33)]:
        for px, py in pips[v]:
            g.append(f'<circle cx="{px*15}" cy="{oy+py*15}" r="6" fill="{INK}"/>')
    g.append("</g>")
    return "".join(g)
chain = "".join(tile(80 + i * 62, 300 - i * 6, -8 + i * 13, (i * 2) % 7, (i * 3 + 1) % 7) for i in range(5))
covers["domino"] = svg(chain + tile(200, 150, -20, 6, 6) + sparkle(90, 90, 1.2) + sparkle(320, 110, 0.9) + sparkle(300, 420, 0.7),
                       "#7aa6ff", "#2f5fd8", stripes("#ffffff", 0.1, 34, -30))

# 7. Isla de recursos: hexágonos, casa y árbol, olas.
waves = "".join(f'<path d="M{x},{y} q15,-12 30,0 t30,0" fill="none" stroke="#ffffff" stroke-opacity="0.5" stroke-width="5" stroke-linecap="round"/>'
                for x, y in [(40, 120), (290, 90), (60, 420), (280, 440), (320, 300)])
hexes = ""
for (cx, cy, col) in [(200, 250, "#7bc96f"), (140, 205, "#f2c94c"), (260, 205, "#c98b4f"), (140, 295, "#9bd27a"), (260, 295, "#b8b0a8"), (200, 340, "#f2c94c"), (200, 160, "#7bc96f")]:
    hexes += hexagon(cx, cy, 56, col)
house = (f'<g transform="translate(200 236)"><rect x="-22" y="-10" width="44" height="34" rx="5" fill="{RED}" stroke="{INK}" stroke-width="5"/>'
         f'<path d="M-30,-8 L0,-36 L30,-8 Z" fill="#c94b44" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/></g>')
tree = (f'<g transform="translate(140 200)"><rect x="-5" y="0" width="10" height="20" fill="#7a4b2a" stroke="{INK}" stroke-width="4"/>'
        f'<circle cx="0" cy="-12" r="22" fill="#2f8f4e" stroke="{INK}" stroke-width="5"/></g>')
sheep = (f'<g transform="translate(140 296)"><ellipse cx="0" cy="0" rx="20" ry="13" fill="{PAPER}" stroke="{INK}" stroke-width="4"/><circle cx="18" cy="-4" r="7" fill="{INK}"/></g>')
covers["island"] = svg(waves + hexes + house + tree + sheep + sparkle(330, 170, 1.1) + sparkle(70, 300, 0.8),
                       "#5fd0e0", "#1c8aa8", dots("#ffffff", 40, 3, 0.15))

# 8. Mesa de cartas: baraja francesa y fichas.
def suit_face(sym, col):
    return (f'<text x="0" y="22" font-family="DejaVu Sans" font-size="78" font-weight="bold" text-anchor="middle" fill="{col}" stroke="{INK}" stroke-width="2">{sym}</text>')
fan2 = "".join(card(200 + (i - 1) * 70, 240 + abs(i - 1) * 16, (i - 1) * 18, suit_face(s, c), 128, 184)
               for i, (s, c) in enumerate([("♣", "#2c2a4a"), ("♥", RED), ("♠", "#2c2a4a")]))
covers["cards"] = svg(fan2 + chip(90, 400, RED, 30, 12) + chip(130, 382, BLUE, 30, 12) + chip(310, 405, GRN, 30, 12)
                      + sparkle(70, 90, 1.2) + sparkle(330, 80, 0.9),
                      "#ff7a6e", "#c73a3a", stripes("#ffffff", 0.1, 30, 30))

# 9. Mesa libre: tapete con un poco de todo.
felt = (f'<ellipse cx="200" cy="300" rx="170" ry="100" fill="#3fa37a" stroke="{INK}" stroke-width="{SW}"/>'
        f'<ellipse cx="200" cy="292" rx="146" ry="80" fill="none" stroke="#ffffff" stroke-opacity="0.25" stroke-width="4"/>')
pencil = (f'<g transform="translate(300 220) rotate(35)"><rect x="-8" y="-60" width="16" height="96" rx="4" fill="{YEL}" stroke="{INK}" stroke-width="5"/>'
          f'<path d="M-8,36 L0,56 L8,36 Z" fill="#f4d3a0" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/></g>')
covers["sandbox"] = svg(felt + card(130, 270, -18, suit_face("♦", RED), 96, 136) + die(220, 250, 76, 12, 3) + die(290, 320, 62, -22, 6, YEL)
                        + chip(130, 340, BLUE, 26, 10) + chip(160, 356, RED, 26, 10) + token(240, 150, GRN, 0.9) + pencil
                        + sparkle(70, 80, 1.2) + sparkle(340, 110, 0.9),
                        "#ffe08a", "#f0a92a", dots("#ffffff", 32, 4, 0.2))

for key, text in covers.items():
    path = os.path.join(OUT, key + ".svg")
    with open(path, "w") as f:
        f.write(text)
    subprocess.run(["rsvg-convert", "-w", "512", "-h", "640", path, "-o", os.path.join(OUT, key + ".png")], check=True)
print("ok", len(covers))
