# -*- coding: utf-8 -*-
"""
Copia un fichero del PC al iPad por USB (AFC), sin SSH ni servidores.

Usa la libreria libimobiledevice ya extraida en el equipo, llamada por ctypes.
No necesita jailbreak para escribir en la carpeta Media (lo que Filza muestra
como "/var/mobile/Media").

OJO: para AFC la raiz "/" ES /var/mobile/Media. Los dos caminos siguientes
escriben en el mismo sitio y el script acepta cualquiera de los dos:

    /iTwitch.ipa
    /var/mobile/Media/iTwitch.ipa

Uso:
    python tools/afc_put.py <fichero-local> [ruta-en-el-ipad]

Ejemplo:
    python tools/afc_put.py dist/iTwitch-1.0.0-full.ipa /iTwitch.ipa
"""

import ctypes
import os
import sys

RUTA_DLL = os.environ.get(
    "LIBIMOBILEDEVICE",
    r"C:\Users\Loftur\AppData\Local\Temp\libimobiledevice-final\ucrt64\bin\libimobiledevice-1.0.dll",
)

AFC_FOPEN_RDONLY = 1
AFC_FOPEN_RW = 2
AFC_FOPEN_WRONLY = 3
AFC_FOPEN_WR = 4

TAM_TROZO = 256 * 1024


class ErrorAFC(Exception):
    pass


def cargar():
    lib = ctypes.WinDLL(RUTA_DLL)
    vp = ctypes.c_void_p
    lib.idevice_new.argtypes = [ctypes.POINTER(vp), ctypes.c_char_p]
    lib.idevice_new.restype = ctypes.c_int
    lib.idevice_free.argtypes = [vp]
    lib.lockdownd_client_new_with_handshake.argtypes = [vp, ctypes.POINTER(vp), ctypes.c_char_p]
    lib.lockdownd_client_new_with_handshake.restype = ctypes.c_int
    lib.lockdownd_client_free.argtypes = [vp]
    lib.lockdownd_start_service.argtypes = [vp, ctypes.c_char_p, ctypes.POINTER(vp)]
    lib.lockdownd_start_service.restype = ctypes.c_int
    lib.lockdownd_service_descriptor_free.argtypes = [vp]
    lib.afc_client_new.argtypes = [vp, vp, ctypes.POINTER(vp)]
    lib.afc_client_new.restype = ctypes.c_int
    lib.afc_client_free.argtypes = [vp]
    lib.afc_file_open.argtypes = [vp, ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_uint64)]
    lib.afc_file_open.restype = ctypes.c_int
    lib.afc_file_write.argtypes = [vp, ctypes.c_uint64, ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32)]
    lib.afc_file_write.restype = ctypes.c_int
    lib.afc_file_close.argtypes = [vp, ctypes.c_uint64]
    lib.afc_file_close.restype = ctypes.c_int
    lib.afc_make_directory.argtypes = [vp, ctypes.c_char_p]
    lib.afc_make_directory.restype = ctypes.c_int
    lib.afc_get_file_info.argtypes = [vp, ctypes.c_char_p, ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p))]
    lib.afc_get_file_info.restype = ctypes.c_int
    return lib


def conectar(lib):
    dispositivo = ctypes.c_void_p()
    estado = lib.idevice_new(ctypes.byref(dispositivo), None)
    if estado != 0:
        raise ErrorAFC("no hay ningun dispositivo conectado (codigo %d)" % estado)

    cliente = ctypes.c_void_p()
    estado = lib.lockdownd_client_new_with_handshake(dispositivo, ctypes.byref(cliente), b"itwitch-afc")
    if estado != 0:
        raise ErrorAFC("lockdownd no responde (codigo %d); acepta el aviso de confianza en el iPad" % estado)

    servicio = ctypes.c_void_p()
    estado = lib.lockdownd_start_service(cliente, b"com.apple.afc", ctypes.byref(servicio))
    if estado != 0:
        raise ErrorAFC("el servicio AFC no esta disponible (codigo %d)" % estado)

    afc = ctypes.c_void_p()
    estado = lib.afc_client_new(dispositivo, servicio, ctypes.byref(afc))
    if estado != 0:
        raise ErrorAFC("no se pudo abrir AFC (codigo %d)" % estado)

    return dispositivo, cliente, servicio, afc


def existe(lib, afc, ruta):
    info = ctypes.POINTER(ctypes.c_char_p)()
    estado = lib.afc_get_file_info(afc, ruta.encode("utf-8"), ctypes.byref(info))
    return estado == 0


def ruta_afc(ruta):
    """El servicio AFC usa /var/mobile/Media como raiz, asi que
    /var/mobile/Media/iTwitch.ipa y /iTwitch.ipa son el mismo sitio."""
    prefijo = "/var/mobile/Media"
    if ruta == prefijo:
        return "/"
    if ruta.startswith(prefijo + "/"):
        return ruta[len(prefijo):]
    return ruta


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    origen = sys.argv[1]
    destino = sys.argv[2] if len(sys.argv) > 2 else "/" + os.path.basename(origen)
    destino = ruta_afc(destino)

    if not os.path.isfile(origen):
        print("No existe el fichero local: %s" % origen)
        return 2

    lib = cargar()
    dispositivo = cliente = servicio = afc = None
    try:
        dispositivo, cliente, servicio, afc = conectar(lib)
        print("  iPad conectado. Copiando %s -> %s" % (os.path.basename(origen), destino))

        # Crear la carpeta si no existe (solo un nivel: /Downloads)
        carpeta = destino.rsplit("/", 1)[0]
        if carpeta and not existe(lib, afc, carpeta):
            lib.afc_make_directory(afc, carpeta.encode("utf-8"))

        if existe(lib, afc, destino):
            print("  Ya existia; se sobrescribe.")

        handle = ctypes.c_uint64(0)
        estado = lib.afc_file_open(afc, destino.encode("utf-8"), AFC_FOPEN_WRONLY, ctypes.byref(handle))
        if estado != 0:
            raise ErrorAFC("no se pudo crear el fichero en el iPad (codigo %d)" % estado)

        total = os.path.getsize(origen)
        enviado = 0
        with open(origen, "rb") as f:
            while True:
                trozo = f.read(TAM_TROZO)
                if not trozo:
                    break
                escrito = ctypes.c_uint32(0)
                estado = lib.afc_file_write(afc, handle, trozo, len(trozo), ctypes.byref(escrito))
                if estado != 0 or escrito.value != len(trozo):
                    raise ErrorAFC("fallo al escribir (codigo %d, %d de %d bytes)" % (estado, escrito.value, len(trozo)))
                enviado += escrito.value
                print("  %3d%%  %d/%d bytes" % (enviado * 100 // total, enviado, total), end="\r")
                sys.stdout.flush()

        lib.afc_file_close(afc, handle)
        print("")
        if enviado != total:
            print("  AVISO: se enviaron %d de %d bytes" % (enviado, total))
            return 1
        print("  LISTO: %s (%d bytes)" % (destino, total))
        return 0
    except ErrorAFC as e:
        print("  ERROR: %s" % e)
        return 1
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
