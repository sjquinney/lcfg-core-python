import pytest

from lcfg_core.common import LCFGChange, LCFGMergeRule
from lcfg_core.packages import LCFGPackage, LCFGPackageList

def test_pkglist_merge_package():
    l1 = LCFGPackageList()
    assert l1.size == 0

    l1.merge_rules = LCFGMergeRule.SQUASH_IDENTICAL

    p1 = LCFGPackage(name="foo")

    change = l1.merge_package(p1)
    assert change == LCFGChange.ADDED
    assert l1.size == 1
    assert "foo" in l1

    change = l1.merge_package(p1)
    assert change == LCFGChange.NONE
    assert l1.size == 1

    p2 = LCFGPackage(name="bar",arch="amd64")
    l1 += p2
    assert l1.size == 2
    assert "bar" in l1
    assert ("bar","amd64") in l1

    # test attempted merge of invalid package (no name)
    invalid_pkg = LCFGPackage()

    with pytest.raises(RuntimeError,match="Failed to merge package: "):
        change = l1.merge_package(invalid_pkg)
