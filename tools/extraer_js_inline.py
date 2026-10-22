# -*- coding: utf-8 -*-
"""
Extrae el JavaScript inline de app/Resources/start.html y lo imprime en stdout.
Sirve para pasarlo a `node --check` en el CI.

Uso:
    python tools/extraer_js_inline.py > /tmp/start-inline.js
"""

import os
import re
import sys

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = _BASE
if "--raiz" in sys.argv:
    i = sys.argv.index("--raiz")
    if i + 1 < len(sys.argv):
        RAIZ = os.path.abspath(sys.argv[i + 1])

RUTA = os.path.join(RAIZ, "app", "Resources", "start.html")

with open(RUTA, encoding="utf-8") as f:
    html = f.read()

patron = re.compile(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>",
                    re.IGNORECASE | re.DOTALL)

for bloque in patron.findall(html):
    sys.stdout.write(bloque)
    sys.stdout.write("\n;\n")

if not patron.search(html):
    sys.stderr.write("No se encontro JavaScript inline en start.html\n")
