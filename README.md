# TriCore GCC toolchain (Nix)

A reproducible C/C++ cross toolchain for the Infineon AURIX **TriCore**
architecture (`x86_64-linux` → `tricore-elf`), built hermetically with Nix.

- GCC 13.4
- Binutils 2.40
- newlib (Cygwin fork) as the C library

Everything is pinned: the gcc/binutils/newlib sources are flake inputs and the
gmp/mpfr/mpc/isl tarballs are hash-pinned, so the build fetches nothing at build
time and produces the same toolchain on any machine.

## Use it

```sh
# drop into a shell with tricore-elf-gcc already on $PATH
nix develop

tricore-elf-gcc -O2 -c main.c -o main.o
```

or build the toolchain into `./result`:

```sh
nix build
./result/bin/tricore-elf-gcc --version
```

The first `nix build` / `nix develop` on a machine compiles the whole toolchain
(~1 h). After that it's cached in `/nix/store`; point Nix at a binary cache to
have other machines download it prebuilt instead of building.

## Bumping a source

The toolchain sources are pinned as flake inputs (no git submodules). To move to
a newer revision, edit its `rev` in `flake.nix` and run `nix flake lock`.

## Credits

Downstream of [NoMore201/tricore-gcc-toolchain](https://github.com/NoMore201/tricore-gcc-toolchain),
itself based on [EEESlab/tricore-gcc-toolchain-11.3.0](https://github.com/EEESlab/tricore-gcc-toolchain-11.3.0).
This fork is reduced to a Nix-only gcc/binutils/newlib build (no qemu, gdb, or
Windows cross).
