# -*- coding: utf-8 -*-
"""Lista un directorio del iPad por USB (AFC). Uso: python tools/afc_ls.py [ruta]"""
import ctypes
import importlib.util
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("afc_put", os.path.join(AQUI, "afc_put.py"))
afc_put = importlib.util.module_from_spec(spec)
spec.loader.exec_module(afc_put)


def main():
    ruta = sys.argv[1] if len(sys.argv) > 1 else "/var/mobile/Media/Downloads"
    lib = afc_put.cargar()
    lib.afc_read_directory.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                       ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p))]
    lib.afc_read_directory.restype = ctypes.c_int
    lib.afc_get_file_info.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                      ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p))]
    lib.afc_get_file_info.restype = ctypes.c_int

    dispositivo = cliente = servicio = afc = None
    try:
        dispositivo, cliente, servicio, afc = afc_put.conectar(lib)

        lista = ctypes.POINTER(ctypes.c_char_p)()
        estado = lib.afc_read_directory(afc, ruta.encode("utf-8"), ctypes.byref(lista))
        if estado != 0:
            print("  No se pudo leer %s (codigo %d)" % (ruta, estado))
            return 1

        nombres = []
        i = 0
        while True:
            valor = lista[i]
            if not valor:
                break
            nombres.append(valor.decode("utf-8", "replace"))
            i += 1

        print("  %s" % ruta)
        for nombre in nombres:
            if nombre in (".", ".."):
                continue
            completa = ruta.rstrip("/") + "/" + nombre
            info = ctypes.POINTER(ctypes.c_char_p)()
            tam = "-"
            if lib.afc_get_file_info(afc, completa.encode("utf-8"), ctypes.byref(info)) == 0:
                pares = {}
                j = 0
                while info[j]:
                    clave = info[j].decode("utf-8", "replace")
                    valor = info[j + 1]
                    pares[clave] = valor.decode("utf-8", "replace") if valor else ""
                    j += 2
                if pares.get("st_size") is not None:
                    tam = pares["st_size"]
            print("    %-40s %s" % (nombre, tam))
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
