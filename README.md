# lcfg-core-python

Python bindings for LCFG core libraries

## Description

This project aims to provide a complete interface to the LCFG core
libraries. However, currently it only supports working with package
specifications and lists.

## Synopsis

```
 from lcfg_core.packages import LCFGPackage, LCFGPackageSet

 # Parse a package specification and add it to a package collection

 pkg = LCFGPackage("foobar-1-2/noarch")
 
 packages = LCFGPackageSet()
 packages.merge_package(pkg)

 # Generate a list of all valid RPM packages in a directory

 rpmlist = LCFGPackageSet.from_rpm_dir("/var/cache/packages/")
 rpmlist.to_rpmlist("/var/cache/packages/rpmlist")
```

## Requirements

For using the Python modules you will need the LCFG core
libraries. For building the modules you will also need the development
headers. Building the code requires a compiler, only gcc has been
tested but clang is expected to work.

This project only supports Python 3, the oldest version it has been
tested with is 3.7.3, there is no intention to provide any support for
Python 2. It also uses Cython to wrap the C libraries so you will need
that installed to build the Python modules. It has only been tested
with Cython version 0.29.20 (and newer) but may well work with older
versions.

The package is built using setuptools. The testing is done with pytest
and requires the runner plugin.

Optionally, for reading and writing YAML package lists you will need
the ruamel.yaml package.

On Debian/Ubuntu for building the software you can install the
dependencies as:

```
apt install python3-setuptools cython3 python3-dev build-essentials
```

For testing you need:

```
apt install python3-pytest python3-pytest-runner
```
