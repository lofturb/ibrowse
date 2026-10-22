# -*- coding: utf-8 -*-
"""
Comprueba que las fuentes, el Makefile y los metadatos son coherentes.

Uso:
    python tools/comprobar_fuentes.py

No compila nada: evita despistes como olvidar un .m en el Makefile, dejar un
fichero vacio o cambiar el bundle ID en un sitio y no en otro. Pensado para
ejecutarse antes de `make package` (y en el CI).
"""

import os
import plistlib
import re
import sys

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = _BASE
if "--raiz" in sys.argv:
    _i = sys.argv.index("--raiz")
    if _i + 1 < len(sys.argv):
        RAIZ = os.path.abspath(sys.argv[_i + 1])
elif not os.path.isdir(os.path.join(_BASE, "app")):
    # El script no esta en la carpeta tools/ de un proyecto: usa el directorio
    # actual si tiene app/ (util al ejecutarlo desde la raiz).
    if os.path.isdir(os.path.join(os.getcwd(), "app")):
        RAIZ = os.getcwd()
APP = os.path.join(RAIZ, "app")
MAKEFILE = os.path.join(APP, "Makefile")
CONTROL = os.path.join(APP, "control")
INFO = os.path.join(APP, "Resources", "Info.plist")
ENTITLEMENTS = os.path.join(APP, "entitlements.plist")


def error(texto):
    print("  ERROR: %s" % texto)
    return 1


def aviso(texto):
    print("  AVISO: %s" % texto)


def leer_makefile():
    with open(MAKEFILE, encoding="utf-8") as f:
        return f.read()


def nombre_app(makefile):
    m = re.search(r"^\s*APPLICATION_NAME\s*=\s*(\S+)\s*$", makefile, re.M)
    if not m:
        raise RuntimeError("no se encontro APPLICATION_NAME en app/Makefile")
    return m.group(1)


def fuentes_declaradas(makefile, app):
    patron = re.compile(r"^\s*%s_FILES\s*=\s*((?:.*\\\n)*.*)$" % re.escape(app),
                        re.M)
    m = patron.search(makefile)
    if not m:
        raise RuntimeError("no se encontro %s_FILES en app/Makefile" % app)
    texto = m.group(1).replace("\\\n", " ")
    return [x for x in texto.split() if x.endswith(".m")]


def main():
    problemas = 0

    print("=== Fuentes ===")
    if not os.path.isfile(MAKEFILE):
        return error("no existe app/Makefile")
    makefile = leer_makefile()
    try:
        app = nombre_app(makefile)
        declaradas = fuentes_declaradas(makefile, app)
    except RuntimeError as e:
        return error(str(e))

    print("  Aplicacion: %s" % app)
    print("  Fuentes en el Makefile: %d" % len(declaradas))

    en_disco = sorted(n for n in os.listdir(APP)
                      if n.endswith(".m") and os.path.isfile(os.path.join(APP, n)))
    for nombre in en_disco:
        if nombre not in declaradas:
            problemas += error("%s esta en app/ pero no en %s_FILES" % (nombre, app))
    for nombre in declaradas:
        if not os.path.isfile(os.path.join(APP, nombre)):
            problemas += error("%s esta en %s_FILES pero no existe" % (nombre, app))
        elif os.path.getsize(os.path.join(APP, nombre)) == 0:
            problemas += error("%s esta vacio" % nombre)

    print("")
    print("=== Metadatos ===")
    try:
        with open(INFO, "rb") as f:
            info = plistlib.load(f)
    except Exception as e:  # noqa: BLE001
        return error("no se pudo leer app/Resources/Info.plist: %s" % e)

    try:
        with open(CONTROL, encoding="utf-8") as f:
            control = f.read()
    except Exception as e:  # noqa: BLE001
        return error("no se pudo leer app/control: %s" % e)

    paquete = re.search(r"^Package:\s*(\S+)", control, re.M)
    version = re.search(r"^Version:\s*(\S+)", control, re.M)
    paquete = paquete.group(1) if paquete else None
    version = version.group(1) if version else None

    bundle = info.get("CFBundleIdentifier")
    ejecutable = info.get("CFBundleExecutable")
    version_info = info.get("CFBundleShortVersionString")
    minimo = info.get("MinimumOSVersion")

    print("  Bundle ID (Info.plist): %s" % bundle)
    print("  Paquete (control):      %s" % paquete)
    print("  Ejecutable:             %s" % ejecutable)
    print("  Version (Info.plist):   %s" % version_info)
    print("  Version (control):      %s" % version)
    print("  iOS minimo:             %s" % minimo)

    if bundle != paquete:
        problemas += error("CFBundleIdentifier y Package no coinciden")
    if ejecutable != app:
        problemas += error("CFBundleExecutable (%s) no coincide con "
                           "APPLICATION_NAME (%s)" % (ejecutable, app))
    if version_info != version:
        problemas += error("CFBundleShortVersionString y Version no coinciden")
    if not minimo:
        problemas += error("falta MinimumOSVersion en Info.plist")
    elif str(minimo) not in ("9.0", "9.0.0"):
        aviso("MinimumOSVersion es %s (el objetivo es 9.0)" % minimo)
    if "UILaunchImages" not in info:
        aviso("falta UILaunchImages: iOS 9 puede mostrar barras negras")

    print("")
    print("=== Entitlements ===")
    if os.path.isfile(ENTITLEMENTS):
        try:
            with open(ENTITLEMENTS, "rb") as f:
                ent = plistlib.load(f)
        except Exception as e:  # noqa: BLE001
            return error("no se pudo leer app/entitlements.plist: %s" % e)
        ident = ent.get("application-identifier")
        grupos = ent.get("keychain-access-groups") or []
        print("  application-identifier: %s" % ident)
        print("  keychain-access-groups: %s" % grupos)
        if ident and bundle and ident != bundle:
            problemas += error("application-identifier no coincide con "
                               "CFBundleIdentifier")
        if grupos and bundle and bundle not in grupos:
            aviso("el bundle ID no esta en keychain-access-groups")
    else:
        aviso("no existe app/entitlements.plist (no habra llavero ni Media)")

    print("")
    if problemas:
        print("=== Resultado: %d problema(s) ===" % problemas)
        return 1
    print("=== Resultado: correcto ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
