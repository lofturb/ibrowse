# -*- coding: utf-8 -*-
"""
Borra una ruta del iPad por USB (AFC). Las rutas son relativas a Media,
que es la raiz del servicio: "/" = /var/mobile/Media.

Uso: python tools/afc_rm.py <ruta>
"""
import ctypes
import importlib.util
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("afc_put", os.path.join(AQUI, "afc_put.py"))
afc_put = importlib.util.module_from_spec(spec)
spec.loader.exec_module(afc_put)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    ruta = sys.argv[1]
    lib = afc_put.cargar()
    lib.afc_remove_path.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.afc_remove_path.restype = ctypes.c_int

    dispositivo = cliente = servicio = afc = None
    try:
        dispositivo, cliente, servicio, afc = afc_put.conectar(lib)
        estado = lib.afc_remove_path(afc, ruta.encode("utf-8"))
        if estado != 0:
            print("  No se pudo borrar %s (codigo %d)" % (ruta, estado))
            return 1
        print("  Borrado: %s" % ruta)
        return 0
    finally:
        if afc:
            lib.afc_client_free(afc)
        if servicio:
            lib.lockdownd_service_descriptor_free(servicio)
        if cliente:
            lib.lockdownd_client_free(cliente)
        if dispositivo:
            lib.idevice_free(dispositivo)


if __name__ == "__main__":
    sys.exit(main())
