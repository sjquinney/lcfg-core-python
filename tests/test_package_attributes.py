import pytest

from lcfg_core.packages import LCFGPackage

def test_package_name():
    p1 = LCFGPackage(name="name1")

    assert p1.has_name()
    assert p1.name == "name1"

    p2 = LCFGPackage()
    assert not p2.has_name()

    p2.name = "name2"
    assert p2.has_name()
    assert p2.name == "name2"

    p2.name = "name-3"
    assert p2.name == "name-3"

    with pytest.raises(TypeError):
        p2.name = 2

    with pytest.raises(ValueError,match="Invalid name '-invalid4'"):
        p1.name = "-invalid4"

    with pytest.raises(ValueError,match="Invalid name 'invalid:5'"):
        p1.name = "invalid:5"

    with pytest.raises(ValueError,match="Invalid name: empty string"):
        p1.name = None

    with pytest.raises(ValueError,match="Invalid name: empty string"):
        p1.name = ""

    with pytest.raises(ValueError,match="Invalid name 'in valid'"):
        p_invalid = LCFGPackage(name="in valid")

def test_package_architecture():
    p1 = LCFGPackage(name="name1",arch="i386")

    assert p1.has_arch()
    assert p1.arch == "i386"

    p2 = LCFGPackage(name="name2")

    assert not p2.has_arch()

    p2.arch = "x86_64"

    assert p2.has_arch()
    assert p2.arch == "x86_64"

    p2.arch = "amd64"
    assert p2.arch == "amd64"

    with pytest.raises(TypeError):
        p1.arch = 2

    with pytest.raises(ValueError,match="Invalid architecture: empty string"):
        p1.arch = None

    with pytest.raises(ValueError,match="Invalid architecture: empty string"):
        p1.arch = ''

    with pytest.raises(ValueError,match="Invalid architecture 'i 386'"):
        p1.arch = "i 386"

    with pytest.raises(ValueError,match="Invalid architecture 'in valid'"):
        p_invalid = LCFGPackage(name="name1", arch="in valid")

def test_package_version():
    p1 = LCFGPackage(name="name1",version="1")

    assert p1.has_version()
    assert p1.version == "1"
    assert p1.full_version == "1"
    assert p1.vra == "1"

    p2 = LCFGPackage(name="name2")

    assert not p2.has_version()

    p2.version = "2"

    assert p2.has_version()
    assert p2.version == "2"
    assert p2.full_version == "2"
    assert p2.vra == "2"

    p2.version = 3
    assert p2.version == "3"
    assert p2.full_version == "3"
    assert p2.vra == "3"

    assert p2.epoch == 0
    p2.version = "1:10"
    assert p2.epoch == 1

    assert p2.full_version == "1:10"
    assert p2.vra == "1:10"

    with pytest.raises(ValueError,match="Invalid version: empty string"):
        p1.version = None

    with pytest.raises(ValueError,match="Invalid version: empty string"):
        p1.version = ''

    with pytest.raises(ValueError,match="Invalid version 'in valid'"):
        p_invalid = LCFGPackage(name="name1", version="in valid")

def test_package_release():
    p1 = LCFGPackage(name="name1",release="1")

    assert p1.has_release()
    assert p1.release == "1"
    assert p1.full_version == "*-1"
    assert p1.vra == "*-1"

    p2 = LCFGPackage(name="name2")

    assert not p2.has_release()

    p2.release = "2"

    assert p2.has_release()
    assert p2.release == "2"
    assert p2.full_version == "*-2"
    assert p2.vra == "*-2"

    p2.release = 3
    assert p2.release == "3"
    assert p2.full_version == "*-3"
    assert p2.vra == "*-3"

    with pytest.raises(ValueError,match="Invalid release: empty string"):
        p1.release = None

    with pytest.raises(ValueError,match="Invalid release: empty string"):
        p1.release = ''

    with pytest.raises(ValueError,match="Invalid release 'in valid'"):
        p_invalid = LCFGPackage(name="name1", release="in valid")

def test_package_flags():
    p1 = LCFGPackage(name="name1",flags="ab")

    assert p1.has_flags()
    assert p1.flags == "ab"

    assert p1.has_flag("a")
    assert p1.has_flag("b")
    assert not p1.has_flag("z")
    with pytest.raises(ValueError,match="Flags are single characters"):
        p1.has_flag("ab")

    p1.clear_flags()
    assert not p1.has_flags()
    assert p1.flags is None

    p1.flags = "ab"
    assert p1.flags == "ab"
    del(p1.flags)
    assert p1.flags is None

    p1.flags = "ab"
    assert p1.flags == "ab"
    p1.flags = ""
    assert p1.flags is None

    p1.flags = "ab"
    assert p1.flags == "ab"
    p1.flags = None
    assert p1.flags is None

    p1.add_flags("c")
    assert p1.flags == "c"

    p1.add_flags("c")
    assert p1.flags == "c"

    p1.add_flags("d")
    assert p1.flags == "cd"

    with pytest.raises(ValueError,match="Invalid flag '!'"):
        p1.flags = "a!b"

    with pytest.raises(ValueError,match="Invalid flag '!'"):
        p1.add_flags("!")
    assert p1.flags == "cd"

    with pytest.raises(ValueError,match="Invalid flag '!'"):
        p2 = LCFGPackage( name="name", flags="!" )

def test_package_context():
    p1 = LCFGPackage(name="name1", context="foo|bar")

    assert p1.has_context()
    assert p1.context == "foo|bar"

    with pytest.raises(ValueError,match="Invalid context: empty string"):
        p1.context = ""

    with pytest.raises(ValueError,match="Invalid context: empty string"):
        p1.context = None

    p2 = LCFGPackage(name="name2")

    assert not p2.has_context()
    p2.context = "foo"
    assert p2.has_context()
    assert p2.context == "foo"

    p2.add_context("bar")
    assert p2.context == "(bar) & (foo)"

    with pytest.raises(ValueError,match="Invalid context: empty string"):
        p2.add_context("")

def test_package_derivation():
    p1 = LCFGPackage(name="name1", derivation="head1.h:10")

    assert p1.has_derivation()
    assert p1.derivation == "head1.h:10"

    with pytest.raises(ValueError,match="Invalid derivation: empty string"):
        p1.derivation = ""

    with pytest.raises(ValueError,match="Invalid derivation: empty string"):
        p1.derivation = None

    p2 = LCFGPackage(name="name2")

    assert not p2.has_derivation()
    p2.derivation = "head2.h:5"
    assert p2.has_derivation()
    assert p2.derivation == "head2.h:5"

    p2.add_derivation("head2.h:5")
    assert p2.derivation == "head2.h:5"

    p2.add_derivation("head2.h:7")
    assert p2.derivation == "head2.h:5,7"

    p2.add_derivation("head3.h:15")
    assert p2.derivation == "head2.h:5,7 head3.h:15"

    p2.add_derivation_file_line("head4.h", 100)
    assert p2.derivation == "head2.h:5,7 head3.h:15 head4.h:100"

    with pytest.raises(ValueError,match="Invalid derivation: empty string"):
        p2.add_derivation("")

def test_package_category():
    p1 = LCFGPackage(name="name1", category="core")

    assert p1.has_category()
    assert p1.category == "core"

    with pytest.raises(ValueError,match="Invalid category: empty string"):
        p1.category = ""

    with pytest.raises(ValueError,match="Invalid category: empty string"):
        p1.category = None

    p2 = LCFGPackage(name="name2")

    assert not p2.has_category()
    p2.category = "foo"
    assert p2.has_category()
    assert p2.category == "foo"

    with pytest.raises(ValueError,match="Invalid category 'foo bar'"):
        p2.category = "foo bar"
    assert p2.category == "foo"

@pytest.mark.parametrize('good_prefix', ['+','-','?','!','~','>'])
def test_package_good_prefix(good_prefix):
    p1 = LCFGPackage(name="name1", prefix=good_prefix)
    assert p1.has_prefix()
    assert p1.prefix == good_prefix

    p1.prefix = ""
    assert not p1.has_prefix()

    p2 = LCFGPackage(name="name2")
    assert not p2.has_prefix()
    p2.prefix = good_prefix
    assert p2.has_prefix()
    assert p2.prefix == good_prefix

    del(p2.prefix)
    assert not p2.has_prefix()

def test_package_bad_prefix():
    p1 = LCFGPackage(name="name1")

    with pytest.raises(ValueError,match="Invalid prefix 'foo': must be a single character"):
        p1.prefix = "foo"

    with pytest.raises(ValueError,match="Invalid prefix '@'"):
        p1.prefix = "@"

    with pytest.raises(ValueError,match="Invalid prefix '1'"):
        p1.prefix = "1"

def test_package_priority():
    p1 = LCFGPackage(name="name1")

    assert p1.priority == 0
    assert p1.is_active()

    p1.priority = 1
    assert p1.priority == 1
    assert p1.is_active()

    p1.priority = -1
    assert p1.priority == -1
    assert not p1.is_active()

    p2 = LCFGPackage(name="name2", priority=-1)
    assert p2.priority == -1
    assert not p2.is_active()

    with pytest.raises(TypeError):
        p1.priority = "foo"
