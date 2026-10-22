# -*- coding: utf-8 -*-
"""
Lista los metodos Objective-C de un binario Mach-O con su direccion, y localiza
cual contiene una direccion dada (util para simbolizar informes de fallo sin
dSYM).

Uso:
    python tools/simbolizar_objc.py <binario> <offset> [offset2 ...]
"""
import struct
import sys


class MachO:
    def __init__(self, ruta):
        with open(ruta, "rb") as f:
            self.data = f.read()
        magic = struct.unpack_from("<I", self.data, 0)[0]
        if magic != 0xFEEDFACE:
            raise SystemExit("no es Mach-O de 32 bits little-endian (magic %08x)" % magic)
        self.ncmds = struct.unpack_from("<I", self.data, 16)[0]
        self.sizeofcmds = struct.unpack_from("<I", self.data, 20)[0]
        self.secciones = {}
        self.secciones_lista = []
        self._leer_comandos()

    def _leer_comandos(self):
        pos = 28
        fin = pos + self.sizeofcmds
        while pos < fin:
            cmd, cmdsize = struct.unpack_from("<II", self.data, pos)
            if cmd == 0x1:  # LC_SEGMENT
                nsects = struct.unpack_from("<I", self.data, pos + 48)[0]
                sp = pos + 56
                for _ in range(nsects):
                    nombre = self.data[sp:sp + 16].rstrip(b"\0").decode("ascii", "replace")
                    addr, size = struct.unpack_from("<II", self.data, sp + 32)
                    offset = struct.unpack_from("<I", self.data, sp + 40)[0]
                    seccion = (nombre, addr, size, offset)
                    self.secciones[nombre] = seccion
                    self.secciones_lista.append(seccion)
                    sp += 68
            pos += cmdsize

    def offset_de(self, vmaddr):
        for nombre, addr, size, offset in self.secciones_lista:
            if addr <= vmaddr < addr + size:
                return offset + (vmaddr - addr)
        return None

    def leer_u32(self, vmaddr):
        o = self.offset_de(vmaddr)
        if o is None or o + 4 > len(self.data):
            return None
        return struct.unpack_from("<I", self.data, o)[0]

    def leer_cadena(self, vmaddr):
        o = self.offset_de(vmaddr)
        if o is None:
            return None
        fin = self.data.find(b"\0", o)
        return self.data[o:fin].decode("utf-8", "replace")


def _metodos_de_lista(macho, base):
    """Lee un method_list_t y devuelve [(imp, selector)]."""
    salida = []
    if not base:
        return salida
    banderas = macho.leer_u32(base)
    cuenta = macho.leer_u32(base + 4)
    if banderas is None or cuenta is None:
        return salida
    if banderas & 0x80000000:      # listas relativas (iOS 12+)
        return salida
    for j in range(cuenta):
        entrada = base + 8 + j * 12
        sel = macho.leer_cadena(macho.leer_u32(entrada) or 0)
        imp = macho.leer_u32(entrada + 8)
        if sel and imp:
            salida.append((imp, sel))
    return salida


def _nombre_de_clase(macho, clase):
    datos = macho.leer_u32(clase + 16)
    if datos is None:
        return None
    return macho.leer_cadena(macho.leer_u32(datos + 16) or 0)


def metodos(macho):
    metodos = []

    # Clases normales
    if "__objc_classlist" in macho.secciones:
        _, addr, size, _ = macho.secciones["__objc_classlist"]
        for i in range(size // 4):
            clase = macho.leer_u32(addr + i * 4)
            if not clase:
                continue
            datos = macho.leer_u32(clase + 16)
            if datos is None:
                continue
            nombre = macho.leer_cadena(macho.leer_u32(datos + 16) or 0) or "?"
            for imp, sel in _metodos_de_lista(macho, macho.leer_u32(datos + 20)):
                metodos.append((imp, nombre, sel))

    # Categorias: name, cls, instanceMethods, classMethods, protocols, properties
    for seccion in ("__objc_catlist", "__objc_nlcatlist"):
        if seccion not in macho.secciones:
            continue
        _, addr, size, _ = macho.secciones[seccion]
        for i in range(size // 4):
            categoria = macho.leer_u32(addr + i * 4)
            if not categoria:
                continue
            clase = macho.leer_u32(categoria + 4)
            nombre = (_nombre_de_clase(macho, clase) if clase else None) or "?"
            for desplazamiento in (8, 12):
                base = macho.leer_u32(categoria + desplazamiento)
                for imp, sel in _metodos_de_lista(macho, base):
                    metodos.append((imp, nombre, sel))

    return metodos


def main():
    macho = MachO(sys.argv[1])
    lista = metodos(macho)
    lista.sort()
    print("metodos Objective-C: %d" % len(lista))

    for texto in sys.argv[2:]:
        objetivo = int(texto, 0)
        print("")
        print("=== 0x%X" % objetivo)
        anterior = None
        siguiente = None
        for imp, clase, sel in lista:
            if imp <= objetivo:
                anterior = (imp, clase, sel)
            elif siguiente is None:
                siguiente = (imp, clase, sel)
                break
        if anterior:
            print("  metodo: -[%s %s]  (0x%X, +0x%X)" % (anterior[1], anterior[2], anterior[0], objetivo - anterior[0]))
        else:
            print("  antes del primer metodo")
        if siguiente:
            print("  siguiente: -[%s %s] (0x%X)" % (siguiente[1], siguiente[2], siguiente[0]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
