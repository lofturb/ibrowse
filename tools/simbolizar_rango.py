# -*- coding: utf-8 -*-
"""Vuelca los metodos Objective-C cuya direccion cae en un rango."""
import importlib.util
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("s", os.path.join(AQUI, "simbolizar_objc.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

b = m.MachO(sys.argv[1])
desde = int(sys.argv[2], 0)
hasta = int(sys.argv[3], 0)

lista = m.metodos(b)
for imp, clase, sel in sorted(lista):
    if desde <= imp <= hasta:
        print("0x%06X  [%s %s]" % (imp, clase, sel))
