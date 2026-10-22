# -*- coding: utf-8 -*-
"""
Genera los iconos e imagenes de arranque de IBrowse sin dependencias externas.

Escribe PNGs a mano con zlib + struct, asi que funciona en Windows con
Python 3.8 sin Pillow.

El motivo es la brujula de la pagina de inicio: fondo azul noche, anillo
claro y aguja blanca/azul.

Uso (desde la raiz del proyecto):
    python tools/generar_recursos.py
"""

import io
import os
import struct
import sys
import zlib


def raiz_proyecto():
    if "--raiz" in sys.argv:
        i = sys.argv.index("--raiz")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])
    actual = os.getcwd()
    if os.path.isdir(os.path.join(actual, "app")):
        return actual
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


RAIZ = raiz_proyecto()
DESTINO = os.path.join(RAIZ, "app", "Resources")

NOCHE_ARRIBA = (0x0A, 0x10, 0x20)
NOCHE_ABAJO = (0x10, 0x25, 0x42)
ANILLO = (0xEC, 0xF3, 0xFF)
AGUJA_CLARA = (0xFF, 0xFF, 0xFF)
AGUJA_AZUL = (0x4F, 0x9B, 0xFF)
CENTRO_OSCURO = (0x0A, 0x10, 0x20)


def escribir_png(ruta, ancho, alto, pixeles):
    """pixeles: bytearray RGBA de ancho*alto*4."""
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n"
                 + bloque(b"IHDR", cabecera)
                 + bloque(b"IDAT", zlib.compress(crudo, 9))
                 + bloque(b"IEND", b""))
    with io.open(ruta, "wb") as f:
        f.write(contenido)


def mezcla(a, b, t):
    return (int(round(a[0] + (b[0] - a[0]) * t)),
            int(round(a[1] + (b[1] - a[1]) * t)),
            int(round(a[2] + (b[2] - a[2]) * t)))


def fondo_vertical(y, alto):
    t = 0.0 if alto <= 1 else y / float(alto - 1)
    return mezcla(NOCHE_ARRIBA, NOCHE_ABAJO, t)


def dentro_del_redondeo(x, y, ancho, alto, radio):
    cx = min(max(x, radio), ancho - radio)
    cy = min(max(y, radio), alto - radio)
    dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radio * radio


def dentro_del_diamante(x, y, cx, cy, ancho, alto):
    dx = abs(x - cx) / float(ancho)
    dy = abs(y - cy) / float(alto)
    return dx + dy <= 1.0


def color_brujula(x, y, lado, transparente_fuera=True):
    """Devuelve RGBA para un punto del icono (lado = ancho/alto)."""
    cx = cy = lado / 2.0
    borde = 0.2237 * lado

    if transparente_fuera and not dentro_del_redondeo(x, y, lado, lado, borde):
        return (0, 0, 0, 0)

    color = fondo_vertical(y, lado)

    # Anillo exterior.
    dx = x - cx
    dy = y - cy
    distancia = (dx * dx + dy * dy) ** 0.5
    radio = 0.355 * lado
    grosor = 0.030 * lado
    if abs(distancia - radio) <= grosor:
        color = ANILLO
    elif abs(distancia - radio * 0.795) <= 0.0045 * lado:
        color = mezcla(color, ANILLO, 0.35)

    # Aguja: rombo vertical, mitad superior clara y mitad inferior azul.
    alto_aguja = 0.285 * lado
    ancho_aguja = 0.118 * lado
    if dentro_del_diamante(x, y, cx, cy, ancho_aguja, alto_aguja):
        if y < cy:
            color = AGUJA_CLARA
        else:
            color = AGUJA_AZUL

    # Eje central.
    if distancia <= 0.058 * lado:
        color = CENTRO_OSCURO
    if distancia <= 0.030 * lado:
        color = ANILLO

    return color + (255,)


def icono(lado, opaco=False):
    """Icono con supermuestreo 3x para bordes suaves."""
    sup = 3
    pixeles = bytearray(lado * lado * 4)

    for y in range(lado):
        for x in range(lado):
            acumulado = [0.0, 0.0, 0.0, 0.0]
            for sy in range(sup):
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup
                    py = y + (sy + 0.5) / sup
                    color = color_brujula(px, py, lado,
                                          transparente_fuera=not opaco)
                    for i in range(4):
                        acumulado[i] += color[i]
            n = sup * sup
            base = (y * lado + x) * 4
            for i in range(4):
                pixeles[base + i] = int(round(acumulado[i] / n))
    return pixeles


def dibujar_marca(pixeles, ancho, alto, centro_x, centro_y, lado):
    """Dibuja la brujula (sin fondo redondeado) sobre un bytearray RGBA."""
    sup = 3
    x0 = int(centro_x - lado / 2)
    y0 = int(centro_y - lado / 2)

    for y in range(max(0, y0), min(alto, y0 + lado)):
        for x in range(max(0, x0), min(ancho, x0 + lado)):
            acumulado = [0.0, 0.0, 0.0, 0.0]
            for sy in range(sup):
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup - x0
                    py = y + (sy + 0.5) / sup - y0
                    color = color_brujula(px, py, lado,
                                          transparente_fuera=False)
                    # Solo pintamos la marca, no el fondo del icono.
                    if color[:3] == fondo_vertical(py, lado):
                        color = (0, 0, 0, 0)
                    elif (abs(color[0] - NOCHE_ARRIBA[0]) < 3 and
                          abs(color[1] - NOCHE_ARRIBA[1]) < 3 and
                          abs(color[2] - NOCHE_ARRIBA[2]) < 3):
                        color = (0, 0, 0, 0)
                    for i in range(4):
                        acumulado[i] += color[i]
            n = sup * sup
            r = int(round(acumulado[0] / n))
            g = int(round(acumulado[1] / n))
            b = int(round(acumulado[2] / n))
            a = int(round(acumulado[3] / n))
            if a <= 0:
                continue
            base = (y * ancho + x) * 4
            # Mezcla sencilla sobre el fondo existente.
            alfa = a / 255.0
            pixeles[base] = int(round(pixeles[base] * (1 - alfa) + r * alfa))
            pixeles[base + 1] = int(round(pixeles[base + 1] * (1 - alfa) + g * alfa))
            pixeles[base + 2] = int(round(pixeles[base + 2] * (1 - alfa) + b * alfa))
            pixeles[base + 3] = 255


def arranque(ancho, alto):
    """Fondo con degradado vertical y la brujula centrada."""
    pixeles = bytearray(ancho * alto * 4)
    for y in range(alto):
        color = fondo_vertical(y, alto)
        fila = bytes((color[0], color[1], color[2], 255)) * ancho
        inicio = y * ancho * 4
        pixeles[inicio:inicio + ancho * 4] = fila

    lado = int(min(ancho, alto) * 0.34)
    dibujar_marca(pixeles, ancho, alto, ancho / 2.0, alto / 2.0, lado)
    return pixeles


ICONOS = [
    ("Icon-Small.png", 29),
    ("Icon-Small@2x.png", 58),
    ("Icon-Small-40.png", 40),
    ("Icon-Small-40@2x.png", 80),
    ("Icon-Small-40@3x.png", 120),
    ("Icon-60.png", 60),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-72.png", 72),
    ("Icon-72@2x.png", 144),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage.png", 320, 480),
    ("LaunchImage@2x.png", 640, 960),
    ("LaunchImage-568h.png", 320, 568),
    ("LaunchImage-568h@2x.png", 640, 1136),
    ("LaunchImage-700.png", 320, 480),
    ("LaunchImage-700@2x.png", 640, 960),
    ("LaunchImage-700-568h.png", 320, 568),
    ("LaunchImage-700-568h@2x.png", 640, 1136),
    ("LaunchImage-700-Portrait.png", 768, 1024),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape.png", 1024, 768),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
]


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    hechos = []

    print("  Raiz:    %s" % RAIZ)
    print("  Destino: %s" % DESTINO)
    print("")

    for nombre, lado in ICONOS:
        print("  icono %s (%dx%d)…" % (nombre, lado, lado))
        escribir_png(os.path.join(DESTINO, nombre), lado, lado,
                     icono(lado, opaco=(nombre == "iTunesArtwork")))
        hechos.append("%s  %dx%d" % (nombre, lado, lado))

    for nombre, ancho, alto in ARRANQUES:
        print("  arranque %s (%dx%d)…" % (nombre, ancho, alto))
        escribir_png(os.path.join(DESTINO, nombre), ancho, alto,
                     arranque(ancho, alto))
        hechos.append("%s  %dx%d" % (nombre, ancho, alto))

    resumen = os.path.join(RAIZ, "app", "recursos-generados.txt")
    with io.open(resumen, "w", encoding="utf-8") as f:
        f.write("Recursos generados por tools/generar_recursos.py\n\n")
        f.write("\n".join(hechos) + "\n")

    print("")
    print("Generados %d archivos en app/Resources" % len(hechos))
    for h in hechos:
        print("   ", h)


if __name__ == "__main__":
    main()
