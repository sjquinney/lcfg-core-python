import pytest

from lcfg_core.packages import LCFGPackageSet

def test_pkgset_new():
    l1 = LCFGPackageSet()
    assert l1.size == 0
    assert len(l1) == 0
    assert not l1

