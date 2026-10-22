# -*- coding: utf-8 -*-
"""
Simboliza direcciones de un binario Mach-O usando LC_FUNCTION_STARTS y LC_SYMTAB.

Uso:
    python tools/simbolizar.py <binario> <offset1> [offset2 ...]

Los offsets son relativos al inicio de __TEXT (lo que queda al restar la
direccion del informe menos la direccion de carga de la imagen).
"""
import struct
import sys


def leer_uleb(data, pos):
    resultado = 0
    desplazamiento = 0
    while True:
        byte = data[pos]
        pos += 1
        resultado |= (byte & 0x7F) << desplazamiento
        desplazamiento += 7
        if not byte & 0x80:
            return resultado, pos


def main():
    ruta = sys.argv[1]
    objetivos = [int(x, 0) for x in sys.argv[2:]]
    with open(ruta, "rb") as f:
        data = f.read()

    magic = struct.unpack_from("<I", data, 0)[0]
    if magic not in (0xFEEDFACE, 0xCEFAEDFE):
        print("no es Mach-O de 32 bits (magic %08x)" % magic)
        return 1
    little = magic == 0xFEEDFACE

    ncmds = struct.unpack_from("<I", data, 16)[0]
    sizeofcmds = struct.unpack_from("<I", data, 20)[0]
    pos = 28
    fin_cmds = pos + sizeofcmds

    secciones = []
    func_starts = None
    symtab = None

    while pos < fin_cmds:
        cmd, cmdsize = struct.unpack_from("<II", data, pos)
        if cmd == 0x26:  # LC_FUNCTION_STARTS
            off, size = struct.unpack_from("<II", data, pos + 8)
            func_starts = (off, size)
        elif cmd == 0x2:  # LC_SYMTAB
            symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", data, pos + 8)
            symtab = (symoff, nsyms, stroff, strsize)
        elif cmd == 0x1:  # LC_SEGMENT
            segname = data[pos + 8:pos + 24].rstrip(b"\0").decode("ascii", "replace")
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<IIII", data, pos + 24)
            nsects = struct.unpack_from("<I", data, pos + 48)[0]
            sp = pos + 56
            for _ in range(nsects):
                sname = data[sp:sp + 16].rstrip(b"\0").decode("ascii", "replace")
                addr, size = struct.unpack_from("<II", data, sp + 32)
                offset = struct.unpack_from("<I", data, sp + 40)[0]
                secciones.append((sname, addr, size, offset))
                sp += 68
            if segname == "__TEXT":
                print("__TEXT vmaddr = 0x%X" % vmaddr)
        pos += cmdsize

    # Funciones
    funciones = []
    if func_starts:
        off, size = func_starts
        bloque = data[off:off + size]
        p = 0
        actual = 0
        while p < len(bloque):
            delta, p = leer_uleb(bloque, p)
            if delta == 0:
                break
            actual += delta
            funciones.append(actual)
    print("funciones detectadas: %d" % len(funciones))

    # Simbolos (nlist 32-bit: 12 bytes)
    simbolos = {}
    if symtab:
        symoff, nsyms, stroff, strsize = symtab
        tabla_str = data[stroff:stroff + strsize]
        for i in range(nsyms):
            base = symoff + i * 12
            if base + 12 > len(data):
                break
            strx, n_type, n_sect, n_desc, n_value = struct.unpack_from("<IBBhI", data, base)
            if n_value == 0 or (n_type & 0x0E) != 0x0E:  # N_SECT
                continue
            fin = tabla_str.find(b"\0", strx)
            nombre = tabla_str[strx:fin].decode("ascii", "replace")
            simbolos.setdefault(n_value, nombre)
    print("simbolos: %d" % len(simbolos))

    for objetivo in objetivos:
        print("")
        print("=== offset 0x%X" % objetivo)
        anterior = None
        for f in funciones:
            if f <= objetivo:
                anterior = f
            else:
                break
        if anterior is None:
            print("  fuera del rango de funciones")
            continue
        print("  funcion empieza en 0x%X (+0x%X)" % (anterior, objetivo - anterior))
        # simbolo mas cercano por debajo o igual
        candidatos = [(v, n) for v, n in simbolos.items() if v <= anterior]
        if candidatos:
            valor, nombre = max(candidatos)
            print("  simbolo mas cercano: %s (0x%X, delta 0x%X)" % (nombre, valor, anterior - valor))
        # seccion
        for sname, addr, size, offset in secciones:
            if addr <= objetivo < addr + size:
                print("  seccion: %s (file offset 0x%X)" % (sname, offset + (objetivo - addr)))
                break
    return 0


if __name__ == "__main__":
    sys.exit(main())
