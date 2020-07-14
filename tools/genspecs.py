#!/usr/bin/python3

from jinja2 import Template
from ruamel.yaml import YAML

names = [ 'foo', 'foo-bar', 'foo+bar' ]

defarch = 'amd64'

archs = [ None, 'i386', 'noarch' ]

versions = [ '*', '1', '100', '5' ]
epochs = [ 0, 2 ]

releases = [ None, '*', '0', '1', '100' ]

prefixes = [ None, '+', '-', '?', '!', '~', '>' ]

flags = [ None, 'b', 'br' ]

contexts = [ None, '!install', 'foo|bar' ]

spec_template = Template('{% if prefix is not none %}{{ prefix }}{% endif %}{{name}}={% if epoch %}{{ epoch }}:{% endif %}{{version}}{% if release is not none %}-{{ release }}{% endif %}{% if arch is not none %}/{{ arch }}{% endif %}{% if flag is not none %}:{{ flag }}{% endif %}{% if context is not none %}[{{context}}]{% endif %}')

rpm_template = Template('{{ name }}-{{ version }}-{{ release }}.{% if arch %}{{ arch }}{% else %}{{ defarch }}{% endif %}.rpm')

deb_template = Template('{{ name }}_{{ version }}-{{ release }}_{% if arch %}{% if arch == "noarch" %}all{% else %}{{ arch }}{% endif %}{% else %}{{ defarch }}{% endif %}.deb')

tests = []

for name in names:
    for arch in archs:
        for version in versions:
            for epoch in epochs:

                for release in releases:
                    if release is None and epoch:
                        release = '*'

                    if release is None:
                        full_version = version
                    else:
                        full_version = '-'.join((version,release))

                    if epoch:
                        full_version = ':'.join((str(epoch),full_version))

                    if arch is None:
                        vra = full_version
                    else:
                        vra = '/'.join((full_version,arch))

                    for prefix in prefixes:
                        for flag in flags:
                            for context in contexts:

                                spec = spec_template.render(name=name, arch=arch, version=version, release=release, prefix=prefix, flag=flag, context=context, epoch=epoch)

                                rpm = None
                                deb = None

                                if version and release:
                                    rpm = rpm_template.render(name=name, arch=arch, version=version, release=release, prefix=prefix, flag=flag, context=context, defarch=defarch)
                                    deb = deb_template.render(name=name, arch=arch, version=version, release=release, prefix=prefix, flag=flag, context=context, defarch=defarch)

                                if epoch:
                                    expected_version = ':'.join((str(epoch),version))
                                else:
                                    expected_version = version

                                attrs = { 'name': name,
                                          'arch': arch,
                                          'version': expected_version,
                                          'release': release,
                                          'epoch': epoch,
                                          'prefix': prefix,
                                          'flags': flag,
                                          'context': context,
                                          'full_version': full_version,
                                          'vra': vra }

                                tests.append({ 'spec': spec,
                                               'rpm': rpm,
                                               'deb': deb,
                                               'attrs': attrs })

yaml = YAML()

with open( '/tmp/testspec.yml', 'w' ) as f:
    yaml.dump( tests, f )
