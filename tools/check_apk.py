"""Fail closed: signed native APK structure; not headset testing."""
import os, pathlib, re, subprocess, sys, zipfile
apk, sdk, slug = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
version = int(sys.argv[4])
mode = sys.argv[5]
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
    assert any('bat_standard' in n for n in names), 'missing standard imported asset'
    assert any('bat_lite' in n for n in names), 'missing lite imported asset'
    assert any('catalog.json' in n for n in names), 'missing asset catalog'
    assert any('xr003' in n.lower() for n in names), 'missing native lobby entry'
    for space in ('intro', 'lobby', 'preview', 'practice', 'settings'):
        assert any('spaces/' + space in n.lower() for n in names), 'missing route: ' + space
meta = run(bt/'aapt', 'dump', 'badging', apk)
assert f"package: name='com.pottersheep.batrunning.xr.{slug}'" in meta, meta
assert 'arm64-v8a' in meta, meta
print(meta)
assert f"versionCode='{version}'" in meta, meta
signed = run(bt/'apksigner', 'verify', '--verbose', '--print-certs', apk)
print(signed)
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signed
cert = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)', signed)
assert cert, 'no certificate fingerprint'
actual = cert.group(1).lower()
if mode == 'release':
    expected = os.environ['XR_CERT_SHA256'].lower().replace(':', '').strip()
    assert actual == expected, 'unexpected release signer'
print('XR_CERT_SHA256=' + actual)
print('XR_VERSION_CODE=' + str(version))
print('APK_STATIC_PASS — installation, tracking and stereo rendering remain unverified')
