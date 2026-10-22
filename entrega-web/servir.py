# -*- coding: utf-8 -*-
"""
Servidor de entrega por HTTP plano para el dispositivo (iOS 9).

Sirve la carpeta actual (o la que indiques con --raiz) para que Safari del
iPhone/iPad pueda descargar el .ipa y los perfiles de certificados. Pensado
para redes locales y equipos antiguos: solo usa la biblioteca estandar de
Python 3, no necesita pip ni permisos especiales (salvo el puerto 80, que en
Windows pide ejecutar como administrador).

Por que no vale "python -m http.server" a secas: iOS 9 necesita que el perfil
.mobileconfig llegue con su tipo MIME correcto. Si llega como binario, Safari
lo descarga pero no ofrece instalarlo. Aqui se declaran:

    .mobileconfig -> application/x-apple-aspen-config
    .ipa          -> application/octet-stream
    .plist        -> application/xml

Uso:
    python servir.py                  # puerto 80, carpeta actual
    python servir.py --puerto 8080
    python servir.py --raiz C:\\ruta\\a\\la\\carpeta
Estructura recomendada:

    entrega/
      index.html
      certificados/CertificadosModernos.mobileconfig
      entrega/MiApp.ipa

La pagina index.html enlaza con rutas relativas, asi que funciona en
cualquier puerto y en cualquier IP.
"""

import argparse
import os
import socket
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

TIPOS = {
    ".mobileconfig": "application/x-apple-aspen-config",
    ".ipa": "application/octet-stream",
    ".plist": "application/xml",
    ".cer": "application/x-x509-ca-cert",
    ".crt": "application/x-x509-ca-cert",
    ".der": "application/x-x509-ca-cert",
    ".mobileprovision": "application/octet-stream",
}


class Manejador(SimpleHTTPRequestHandler):
    extensions_map = dict(SimpleHTTPRequestHandler.extensions_map)
    extensions_map.update(TIPOS)

    def end_headers(self):
        # Que Safari no reutilice un .ipa viejo despues de recompilar.
        self.send_header("Cache-Control", "no-store")
        SimpleHTTPRequestHandler.end_headers(self)

    def log_message(self, formato, *args):
        sys.stderr.write("  %s - %s\n" % (self.address_string(), formato % args))


def ip_local():
    """IP de este PC en la red local (la que debe usar el dispositivo)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:  # noqa: BLE001
        return "127.0.0.1"
    finally:
        s.close()


def main():
    analizador = argparse.ArgumentParser(description="Servidor de entrega para iOS")
    analizador.add_argument("--puerto", type=int, default=80)
    analizador.add_argument("--raiz", default=None,
                            help="carpeta a servir (por defecto, la de este script)")
    args = analizador.parse_args()

    raiz = os.path.abspath(args.raiz or os.getcwd())
    if not os.path.isdir(raiz):
        print("  No existe la carpeta: %s" % raiz)
        return 1
    os.chdir(raiz)

    ip = ip_local()
    print("")
    print("  Servidor de entrega")
    print("  " + "-" * 52)
    print("  Carpeta         %s" % raiz)
    print("  En este PC      http://127.0.0.1:%d/" % args.puerto)
    print("  En el iPad      http://%s:%d/" % (ip, args.puerto))
    print("  " + "-" * 52)
    print("  1. Conecta el dispositivo a la misma WiFi que este PC.")
    print("  2. Abre Safari y entra en la direccion de arriba.")
    print("  3. Instala primero los certificados y luego la app.")
    print("  4. Deja esta ventana abierta. Para parar: Ctrl+C")
    print("")

    try:
        servidor = ThreadingHTTPServer(("0.0.0.0", args.puerto), Manejador)
    except OSError as e:
        print("  No se pudo abrir el puerto %d: %s" % (args.puerto, e))
        print("  Prueba con --puerto 8080 (o ejecuta como administrador para el 80).")
        return 1

    servidor.daemon_threads = True
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\n  Servidor detenido.")
        servidor.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
