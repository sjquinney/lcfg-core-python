import pytest

from lcfg_core.packages import LCFGPackageList

def test_pkglist_new():
    l1 = LCFGPackageList()
    assert l1.size == 0
    assert len(l1) == 0
    assert not l1

