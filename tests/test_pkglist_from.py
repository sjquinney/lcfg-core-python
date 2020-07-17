import pytest

from lcfg_core.common import LCFGChange, LCFGMergeRule
from lcfg_core.packages import LCFGPackage, LCFGPackageList

def test_pkglist_from_rpmlist():

    l1 = LCFGPackageList.from_rpmlist("tests/rpmlist")

    assert l1.size == 9030
