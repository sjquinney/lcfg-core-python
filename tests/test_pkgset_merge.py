import pytest

from lcfg_core.common import LCFGChange, LCFGMergeRule
from lcfg_core.packages import LCFGPackage, LCFGPackageSet

def test_pkgset_merge_package():
    s1 = LCFGPackageSet()
    assert s1.size == 0

    s1.merge_rules = LCFGMergeRule.SQUASH_IDENTICAL

    p1 = LCFGPackage(name="foo")

    change = s1.merge_package(p1)
    assert change == LCFGChange.ADDED
    assert s1.size == 1

    change = s1.merge_package(p1)
    assert change == LCFGChange.NONE
    assert s1.size == 1

    p2 = LCFGPackage(name="bar")
    s1 += p2
    assert s1.size == 2

    # test attempted merge of invalid package (no name)
    invalid_pkg = LCFGPackage()

    with pytest.raises(RuntimeError,match="Failed to merge package: "):
        change = s1.merge_package(invalid_pkg)
