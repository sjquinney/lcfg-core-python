import pytest

from lcfg_core.common import LCFGChange, LCFGMergeRule
from lcfg_core.packages import LCFGPackage, LCFGPackageSet

def test_pkgset_from_rpmlist():

    s1 = LCFGPackageSet.from_rpmlist("tests/rpmlist")

    assert s1.size == 9030
