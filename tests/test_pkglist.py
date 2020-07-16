import pytest

from lcfg_core.common import LCFGMergeRule
from lcfg_core.packages import LCFGPackageList

def test_pkglist_new():
    l1 = LCFGPackageList()
    assert l1.size == 0
    assert len(l1) == 0
    assert l1.is_empty()
    assert not l1

    l1.merge_rules = LCFGMergeRule.KEEP_ALL | LCFGMergeRule.SQUASH_IDENTICAL
    assert l1.merge_rules == 3

