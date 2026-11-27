"""Same signer + version on both platform APKs; no claim of update from XR000."""
import pathlib, re, sys
def read(path):
    text = pathlib.Path(path).read_text()
    return tuple(re.search(key + r'=([^\s]+)', text).group(1) for key in ('XR_CERT_SHA256','XR_VERSION_CODE'))
a, b = map(read, sys.argv[1:])
assert a == b, 'platform signature or version mismatch'
print('XR001_PAIR_PASS', a[0], a[1])
