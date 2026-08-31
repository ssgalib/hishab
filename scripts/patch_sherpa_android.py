#!/usr/bin/env python3
"""Gives sherpa-onnx its own onnxruntime under a private soname.

The sherpa_onnx flutter plugin and onnxruntime-android both ship a
`libonnxruntime.so`. They are different builds (sherpa: 1.27.1 with hidden
OrtGetApiBase; maven: 1.20.0 for the Java API) and cannot be deduped —
Gemma's Java bridge fails to resolve OrtGetApiBase against sherpa's copy.

Fix: rename sherpa's copy to `libsherpa_ort.so` and point sherpa's DT_NEEDED
at it. Both then load side by side:
  - Gemma (Kotlin ai.onnxruntime)  -> libonnxruntime.so   (maven 1.20.0)
  - Speech (sherpa_onnx FFI)       -> libsherpa_ort.so    (1.27.1)

The new name is shorter than the old, so strings are patched in place —
no table resizing. Run again after upgrading the sherpa_onnx packages
(idempotent: already-patched files are skipped).
"""
import os
import struct
import sys

OLD = b'libonnxruntime.so\x00'
NEW = b'libsherpa_ort.so\x00'

DT_NEEDED, DT_SONAME = 1, 14
SHT_DYNAMIC, SHT_STRTAB = 6, 3


def elf_patch_strings(path: str, replacements: dict) -> int:
    """Replaces `old` strings referenced by DT_NEEDED/DT_SONAME entries.

    replacements maps old-bytes -> new-bytes (new must not be longer).
    Returns the number of patched entries.
    """
    data = bytearray(open(path, 'rb').read())
    is64 = data[4] == 2  # EI_CLASS

    if is64:
        e_shoff = struct.unpack_from('<Q', data, 0x28)[0]
        e_shentsize, e_shnum = struct.unpack_from('<H', data, 0x3A)[0], struct.unpack_from('<H', data, 0x3C)[0]
        fmt_entry, fmt_off, fmt_size = '<IIQQ', None, None
    else:
        e_shoff = struct.unpack_from('<I', data, 0x20)[0]
        e_shentsize, e_shnum = struct.unpack_from('<H', data, 0x2E)[0], struct.unpack_from('<H', data, 0x30)[0]

    dyn_off = dyn_size = dyn_link = None
    strtab_off = None
    sections = []
    for i in range(e_shnum):
        base = e_shoff + i * e_shentsize
        sh_type = struct.unpack_from('<I', data, base + 4)[0]
        if is64:
            sh_offset = struct.unpack_from('<Q', data, base + 0x18)[0]
            sh_size = struct.unpack_from('<Q', data, base + 0x20)[0]
            sh_link = struct.unpack_from('<I', data, base + 0x28)[0]
        else:
            sh_offset = struct.unpack_from('<I', data, base + 0x10)[0]
            sh_size = struct.unpack_from('<I', data, base + 0x14)[0]
            sh_link = struct.unpack_from('<I', data, base + 0x18)[0]
        sections.append((sh_type, sh_offset, sh_size, sh_link))
        if sh_type == SHT_DYNAMIC:
            dyn_off, dyn_size, dyn_link = sh_offset, sh_size, sh_link

    if dyn_off is None or dyn_link is None:
        raise RuntimeError(f'{path}: no .dynamic section found')
    if dyn_link >= len(sections):
        raise RuntimeError(f'{path}: bad .dynamic sh_link')
    strtab_off = sections[dyn_link][1]
    if strtab_off is None:
        raise RuntimeError(f'{path}: no .dynstr section found')

    patched = 0
    entsize = 16 if is64 else 8
    for off in range(dyn_off, dyn_off + dyn_size, entsize):
        if is64:
            tag, val = struct.unpack_from('<qQ', data, off)
        else:
            tag, val = struct.unpack_from('<iI', data, off)
        if tag not in (DT_NEEDED, DT_SONAME):
            continue
        pos = strtab_off + val
        end = data.index(b'\x00', pos)
        s = bytes(data[pos:end])
        if s in replacements:
            new = replacements[s]
            if len(new) > len(s):
                raise RuntimeError(f'{path}: replacement longer than original')
            data[pos:pos + len(new)] = new
            data[pos + len(new):end] = b'\x00' * (end - pos - len(new))
            patched += 1

    open(path, 'wb').write(bytes(data))
    return patched


def patch_cache(cache_dir: str) -> None:
    # pub package name -> jniLibs ABI directory
    packages = {
        'sherpa_onnx_android_arm64': 'arm64-v8a',
        'sherpa_onnx_android_armeabi': 'armeabi-v7a',
        'sherpa_onnx_android_x86': 'x86',
        'sherpa_onnx_android_x86_64': 'x86_64',
    }
    for pkg, abi in packages.items():
        jni = os.path.join(
            cache_dir, f'{pkg}-1.13.6', 'android', 'src', 'main', 'jniLibs', abi)
        if not os.path.isdir(jni):
            print(f'skip {abi}: not found')
            continue
        ort = os.path.join(jni, 'libonnxruntime.so')
        renamed = os.path.join(jni, 'libsherpa_ort.so')
        if os.path.exists(renamed):
            print(f'{abi}: already patched')
            continue
        n = elf_patch_strings(ort, {OLD[:-1]: NEW[:-1]})
        os.rename(ort, renamed)
        print(f'{abi}: soname patched ({n} entry) -> libsherpa_ort.so')

        for api in ('libsherpa-onnx-c-api.so', 'libsherpa-onnx-cxx-api.so'):
            p = os.path.join(jni, api)
            if os.path.exists(p):
                n = elf_patch_strings(p, {OLD[:-1]: NEW[:-1]})
                print(f'{abi}: {api} DT_NEEDED patched ({n} entries)')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('cache', nargs='?',
                        default=os.path.expanduser('~/.pub-cache/hosted/pub.dev'))
    args = parser.parse_args()
    patch_cache(args.cache)
