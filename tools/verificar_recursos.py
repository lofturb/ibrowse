# -*- coding: utf-8 -*-
"""
Comprueba que los recursos generados existen, son PNG validos y que el
Info.plist los referencia con los nombres correctos.

Uso:
    python tools/verificar_recursos.py
"""

import os
import plistlib
import struct
import sys

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = _BASE
if "--raiz" in sys.argv:
    i = sys.argv.index("--raiz")
    if i + 1 < len(sys.argv):
        RAIZ = os.path.abspath(sys.argv[i + 1])

RECURSOS = os.path.join(RAIZ, "app", "Resources")
INFO = os.path.join(RECURSOS, "Info.plist")

ICONOS = {
    "Icon-Small.png": (29, 29),
    "Icon-Small@2x.png": (58, 58),
    "Icon-Small-40.png": (40, 40),
    "Icon-Small-40@2x.png": (80, 80),
    "Icon-Small-40@3x.png": (120, 120),
    "Icon-60.png": (60, 60),
    "Icon-60@2x.png": (120, 120),
    "Icon-60@3x.png": (180, 180),
    "Icon-72.png": (72, 72),
    "Icon-72@2x.png": (144, 144),
    "Icon-76.png": (76, 76),
    "Icon-76@2x.png": (152, 152),
    "iTunesArtwork": (512, 512),
}

ARRANQUES = {
    "LaunchImage.png": (320, 480),
    "LaunchImage@2x.png": (640, 960),
    "LaunchImage-568h.png": (320, 568),
    "LaunchImage-568h@2x.png": (640, 1136),
    "LaunchImage-700.png": (320, 480),
    "LaunchImage-700@2x.png": (640, 960),
    "LaunchImage-700-568h.png": (320, 568),
    "LaunchImage-700-568h@2x.png": (640, 1136),
    "LaunchImage-700-Portrait.png": (768, 1024),
    "LaunchImage-700-Portrait@2x.png": (1536, 2048),
    "LaunchImage-700-Landscape.png": (1024, 768),
    "LaunchImage-700-Landscape@2x.png": (2048, 1536),
}

JS = [
    "ibrowse-bridge.js",
    "ibrowse-blocker.js",
    "ibrowse-reader.js",
    "ibrowse-polyfills.js",
]


def error(texto):
    print("  ERROR: %s" % texto)
    return 1


def aviso(texto):
    print("  AVISO: %s" % texto)


def dimensiones_png(ruta):
    with open(ruta, "rb") as f:
        cabecera = f.read(24)
    if len(cabecera) < 24 or cabecera[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    if cabecera[12:16] != b"IHDR":
        return None
    ancho, alto = struct.unpack(">II", cabecera[16:24])
    return ancho, alto


def main():
    problemas = 0

    print("=== Imagenes ===")
    for nombre, esperado in list(ICONOS.items()) + list(ARRANQUES.items()):
        ruta = os.path.join(RECURSOS, nombre)
        if not os.path.isfile(ruta):
            problemas += error("falta %s (ejecuta tools/generar_recursos.py)" % nombre)
            continue
        real = dimensiones_png(ruta)
        if real is None:
            problemas += error("%s no es un PNG valido" % nombre)
        elif real != esperado:
            problemas += error("%s mide %dx%d, se esperaba %dx%d" %
                               (nombre, real[0], real[1], esperado[0], esperado[1]))
    print("  Revisados %d PNG" % (len(ICONOS) + len(ARRANQUES)))

    print("")
    print("=== JavaScript ===")
    for nombre in JS:
        ruta = os.path.join(RECURSOS, nombre)
        if not os.path.isfile(ruta) or os.path.getsize(ruta) < 32:
            problemas += error("falta o esta vacio %s" % nombre)
    print("  %d archivos JS presentes" % len(JS))

    print("")
    print("=== Info.plist ===")
    try:
        with open(INFO, "rb") as f:
            info = plistlib.load(f)
    except Exception as e:  # noqa: BLE001
        return error("no se pudo leer Info.plist: %s" % e)

    for clave in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString",
                  "CFBundleIcons", "CFBundleIcons~ipad", "UILaunchImages"):
        if clave not in info:
            problemas += error("falta %s en Info.plist" % clave)

    iconos = set()
    for clave in ("CFBundleIcons", "CFBundleIcons~ipad"):
        bloque = info.get(clave) or {}
        primario = bloque.get("CFBundlePrimaryIcon") or {}
        for nombre in primario.get("CFBundleIconFiles") or []:
            iconos.add(nombre)
    for nombre in sorted(iconos):
        if not os.path.isfile(os.path.join(RECURSOS, nombre + ".png")):
            problemas += error("Info.plist referencia el icono %s.png y no existe" % nombre)
    print("  Iconos referenciados: %s" % ", ".join(sorted(iconos)))

    for item in info.get("UILaunchImages") or []:
        nombre = item.get("UILaunchImageName")
        if not nombre:
            problemas += error("UILaunchImages tiene una entrada sin nombre")
            continue
        if not os.path.isfile(os.path.join(RECURSOS, nombre + ".png")):
            problemas += error("falta la imagen de arranque %s.png" % nombre)
    print("  Imagenes de arranque: %d" % len(info.get("UILaunchImages") or []))

    print("")
    print("=== HTML ===")
    inicio = os.path.join(RECURSOS, "start.html")
    if not os.path.isfile(inicio):
        problemas += error("falta start.html")
    else:
        with open(inicio, encoding="utf-8") as f:
            html = f.read()
        if "</html>" not in html:
            problemas += error("start.html no termina con </html>")
        if "{{" in html:
            problemas += error("start.html contiene marcadores sin sustituir")
        if "messageHandlers.ibrowse" not in html:
            problemas += error("start.html no usa el puente de IBrowse")
        print("  start.html: %d bytes" % len(html))

    print("")
    if problemas:
        print("=== Resultado: %d problema(s) ===" % problemas)
        return 1
    aviso("recursos correctos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
