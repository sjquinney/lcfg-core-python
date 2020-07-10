import pytest
from ruamel.yaml import YAML

from lcfg_core.packages import LCFGPackage

def pytest_generate_tests(metafunc):
    if 'testspec' in metafunc.fixturenames:
        with open("tests/testspec.yml", 'r') as f:
            yaml = YAML()
            specs = yaml.load(f)
            metafunc.parametrize('testspec', [i for i in specs])

def test_pkg_from_spec(testspec):
    p = LCFGPackage(spec=testspec['spec'])
    assert p.is_valid()

    attrs = testspec['attrs']

    assert p.name    == attrs['name']
    assert p.arch    == attrs['arch']

    assert p.version == attrs['version']
    assert p.epoch   == attrs['epoch']
    assert p.release == attrs['release']
    assert p.vra     == attrs['vra']
    assert p.full_version == attrs['full_version']

    assert p.flags   == attrs['flags']
    assert p.prefix  == attrs['prefix']
    assert p.context == attrs['context']


