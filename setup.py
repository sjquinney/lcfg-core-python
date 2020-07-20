#!/usr/bin/python3

from setuptools import Extension, setup
from Cython.Build import cythonize

ext_modules = [
    Extension("packages",
              sources=["lcfg_core/packages.pyx"],
              libraries=["lcfg_packages","lcfg_utils","lcfg_common"]
              ),
    Extension("resources",
              sources=["lcfg_core/resources.pyx"],
              libraries=["lcfg_resources","lcfg_utils","lcfg_common"]
              )
]

setup(name="LCFG Core",
      ext_package="lcfg_core",
      ext_modules=cythonize(ext_modules, language_level=3, compiler_directives={'c_string_type': 'unicode', 'c_string_encoding': 'default'})
)
