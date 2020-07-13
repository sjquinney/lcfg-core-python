import pytest
from ruamel.yaml import YAML

from lcfg_core.packages import LCFGPackage, LCFGOption

def pytest_generate_tests(metafunc):
    if 'testspec' in metafunc.fixturenames:
        with open("tests/testspec.yml", 'r') as f:
            yaml = YAML()
            specs = yaml.load(f)
            metafunc.parametrize('testspec', [i for i in specs])

def test_pkg_to_spec(testspec):

    attrs = testspec['attrs']

    args = { k:v for (k,v) in testspec['attrs'].items() if v is not None }

    p = LCFGPackage(**args)
    assert p.is_valid()

    assert p.to_spec(options=LCFGOption.NEW) == testspec['spec']

    if 'rpm' in testspec and testspec['rpm']:
        assert p.to_rpm_filename(defarch='amd64') == testspec['rpm']
    else:
        with pytest.raises(RuntimeError,match='Package style requires version and release fields to be defined'):
            p.to_rpm_filename(defarch='amd64')

    if 'deb' in testspec and testspec['deb']:
        assert p.to_deb_filename(defarch='amd64') == testspec['deb']
    else:
        with pytest.raises(RuntimeError,match='Package style requires version and release fields to be defined'):
            p.to_deb_filename(defarch='amd64')
