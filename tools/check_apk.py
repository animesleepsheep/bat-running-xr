"""Fail closed: signed native APK structure; not headset testing."""
import pathlib, subprocess, sys, zipfile
apk, sdk, slug = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
bt = sdk / 'build-tools' / '35.0.1'
def run(*args):
    return subprocess.check_output([str(a) for a in args], stderr=subprocess.STDOUT, text=True)
with zipfile.ZipFile(apk) as z:
    assert z.testzip() is None, 'corrupt APK'
    names = z.namelist()
    assert 'AndroidManifest.xml' in names
    assert any(n.startswith('lib/arm64-v8a/') and n.endswith('.so') for n in names), 'missing arm64 libraries'
    assert any('openxr' in n.lower() and n.endswith('.so') for n in names), 'no OpenXR loader found'
    assert any(n.startswith('assets/') for n in names), 'missing game assets'
meta = run(bt/'aapt', 'dump', 'badging', apk)
assert f"package: name='com.pottersheep.batrunning.xr.{slug}'" in meta, meta
assert 'arm64-v8a' in meta, meta
print(meta)
print(run(bt/'apksigner', 'verify', '--verbose', '--print-certs', apk))
print('APK_STATIC_PASS — installation, tracking and stereo rendering remain unverified')
