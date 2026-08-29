# Meson D (LDC) Linker Ordering Bug Reproducer

This minimal project reproduces a linking failure occurring when building D executables that depend on internal static C libraries which in turn depend on external shared libraries.

## Reproduction Steps

```bash
meson setup _build
ninja -C _build
```

### Observed Output

```text
FAILED: prog 
ldc2  -of=prog prog.p/main.d.o -L=--allow-shlib-undefined -link-defaultlib-shared -L=clib/libclib.a /usr/lib/x86_64-linux-gnu/libavutil.so
/usr/bin/ld: clib/libclib.a.p/clib.c.o: in function `clib_get_version':
.../clib/clib.c:5:(.text+0x9): undefined reference to `av_version_info'
collect2: error: ld returned 1 exit status
```

---

## Root Cause Analysis

1. **Meson Link Flag Generation for D**:
   - Internal static libraries (`link_with: clib_lib`) are passed to `ldc2` with `-L=clib/libclib.a`.
   - External shared library dependencies (`dependencies: avutil_dep`) resolved by pkg-config are passed as raw file arguments without `-L=`, e.g. `/usr/lib/x86_64-linux-gnu/libavutil.so`.

2. **LDC2 Argument Ordering**:
   - `ldc2` treats raw file paths as primary object files and passes them at the beginning of the backend linker (`/usr/bin/cc`) command line.
   - `ldc2` translates `-L=...` arguments into `-Xlinker ...` options placed *after* the raw object/library files.

3. **Backend Linker (`ld`) Single-Pass Resolution**:
   - The resulting linker command line orders the libraries as:
     ```bash
     cc main.d.o ... /usr/lib/.../libavutil.so -o prog -Xlinker clib/libclib.a
     ```
   - When GNU `ld` scans `/usr/lib/.../libavutil.so`, the D object `main.d.o` has not directly referenced `av_version_info`, so the symbol is not loaded from `libavutil.so`.
   - When GNU `ld` later scans `clib/libclib.a`, `clib.c.o` is pulled in and introduces an unresolved reference to `av_version_info`.
   - Because `libavutil.so` was placed earlier on the command line, `ld` does not revisit it, resulting in `undefined reference to 'av_version_info'`.

---

## Expected Fix Verification

When fixed in Meson or LDC:
- The static library `clib/libclib.a` should be passed to the linker *before* its dependent shared libraries (`libavutil.so`), or all dependencies should be passed uniformly in dependency order.
- `ninja -C _build` will succeed and `./_build/prog` will execute and print the version string.
