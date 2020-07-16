import pytest

from lcfg_core.common import LCFGMergeRule
from lcfg_core.packages import LCFGPackageSet

def test_pkgset_new():
    s1 = LCFGPackageSet()
    assert s1.size == 0
    assert len(s1) == 0
    assert s1.is_empty()
    assert not s1

    s1.merge_rules = LCFGMergeRule.KEEP_ALL | LCFGMergeRule.SQUASH_IDENTICAL
    assert s1.merge_rules == 3

