{
  description = "tricore-gcc-toolchain (x86_64-linux -> tricore-elf gcc/binutils/newlib)";

  # Pull the prebuilt toolchain from the binary cache instead of building it.
  # CI (`.github/workflows/build.yml`) builds once and pushes here, so
  # `nix build` / `nix shell` on any machine is a download, not a 40-min compile.
  nixConfig = {
    extra-substituters = [ "https://brandonros.cachix.org" ];
    extra-trusted-public-keys = [
      "brandonros.cachix.org-1:2VlkqIIKqlZ0oWyA4B+R8oa4lGf1YPJSrKnVnCtVjmU="
    ];
  };

  # tricore-elf cross toolchain (gcc + binutils + newlib), built hermetically.
  #
  #   nix build    -> ./result/bin/tricore-elf-*  (the prebuilt toolchain)
  #   nix develop  -> a shell with tricore-elf-gcc already on $PATH
  #
  # Fully offline & reproducible: the gcc/binutils/newlib sources are pinned flake
  # inputs (below) and gmp/mpfr/mpc/isl come from nixpkgs, so nothing is fetched at
  # build time. Those sources used to be git submodules — they're flake
  # inputs now, fed to ./configure via --with-{gcc,binutils,newlib}-src, so the repo
  # needs no submodules. To bump a source: change the rev below and `nix flake lock`.

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  inputs.tricore-gcc = {
    url = "github:NoMore201/tricore-gcc/59834f272d9c0d051329195c867341238b0c6a86";
    flake = false;
  };
  inputs.tricore-binutils-gdb = {
    url = "github:NoMore201/tricore-binutils-gdb/78ccc076bc8cad0f9e08c81ca1c89b5e89dfb8f3";
    flake = false;
  };
  inputs.tricore-newlib-cygwin = {
    url = "github:EEESlab/tricore-newlib-cygwin/240a8f676ea923c703824e996fbe88ac4a302e17";
    flake = false;
  };

  outputs = { self, nixpkgs, tricore-gcc, tricore-binutils-gdb, tricore-newlib-cygwin }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Build GCC/newlib with gcc (not clang); nixpkgs hardening trips the build.
      #
      # Pin to GCC 13, NOT the nixpkgs default (currently GCC 15). GCC 15 defaults
      # to -std=gnu23, where an empty parameter list `g()` means `g(void)`. The
      # old autoconf probes in gmp-6.2.1/mpfr-3.1.6/etc. declare `g()` then call it
      # with arguments, which GCC 15 rejects with a hard error:
      #   error: too many arguments to function 'g'; expected 0, have 6
      # making gmp's configure conclude "could not find a working compiler".
      # CI builds on Ubuntu 24.04 (GCC 13, -std=gnu17), so pin to GCC 13.4.0 here —
      # it also matches this toolchain's own 13.4 release lineage.
      stdenv = pkgs.gcc13Stdenv;

      # gcc/binutils need gmp, mpfr, mpc and isl. Use nixpkgs' (cached, no tarball
      # build): gmp 6.3 / mpfr 4.2 / mpc 1.4 / isl 0.20 — all within GCC 13's
      # accepted ranges. Their include/lib dirs are passed to the Makefile below.
      mathlibs = with pkgs; [ gmp mpfr libmpc isl ];

      # Everything needed to BUILD the toolchain (the package is the only consumer).
      nativeBuildInputs = with pkgs; [
        # autotools + build basics
        gnumake autoconf automake libtool texinfo
        flex bison gperf
        gettext            # --enable-nls
        perl file which patch diffutils gnused gawk gnugrep
        coreutils          # nproc, etc.

        # archive tools the gcc/binutils/newlib build shells out to (e.g. gzip'd
        # info pages during `make install`)
        gnutar bzip2 gzip xz

        # The native (linux -> tricore) build needs *only* the i686 mingw compiler:
        # the build-newlib stage configures with --host=i686-w64-mingw32. Pin it to
        # gcc13 too (default tracks GCC 15) so the newlib host-tool autoconf probes
        # don't hit the same -std=gnu23 breakage described above for the host gcc.
        pkgsCross.mingw32.buildPackages.gcc13     # i686-w64-mingw32-{gcc,g++}
        pkgsCross.mingw32.buildPackages.binutils  # i686-w64-mingw32-{as,ld,ar,...}
      ];

      lib = pkgs.lib;

      # Math-lib include/lib dirs handed to the Makefile's --with-{gmp,mpfr,mpc,isl}.
      mathMakeFlags = [
        "GMP_INCLUDE=${lib.getDev pkgs.gmp}/include"    "GMP_LIB=${lib.getLib pkgs.gmp}/lib"
        "MPFR_INCLUDE=${lib.getDev pkgs.mpfr}/include"  "MPFR_LIB=${lib.getLib pkgs.mpfr}/lib"
        "MPC_INCLUDE=${lib.getDev pkgs.libmpc}/include" "MPC_LIB=${lib.getLib pkgs.libmpc}/lib"
        "ISL_INCLUDE=${lib.getDev pkgs.isl}/include"    "ISL_LIB=${lib.getLib pkgs.isl}/lib"
      ];

      # One build stage = one derivation. The toolchain's Makefile installs every
      # stage into a single shared prefix incrementally, so each stage here copies
      # the previous stage's $out in (the accumulating cross-prefix), marks the
      # earlier stamps as already-done so `make` won't rebuild them, then runs only
      # its own target. Result: a failure/restart in a later stage reuses the earlier
      # stages from the store (or cache) instead of redoing the whole chain.
      mkStage = { pname, target, priorStamps ? [], prev ? null }:
        stdenv.mkDerivation {
          inherit pname;
          version = "13.4.1";

          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [ ./configure.ac ./Makefile.in ];
          };

          inherit nativeBuildInputs;
          buildInputs = mathlibs;       # gmp/mpfr/mpc/isl: -I/-L/-rpath via cc-wrapper
          hardeningDisable = [ "all" ];
          dontStrip = true;             # build already strips host bins (LDFLAGS=-s)

          configurePhase = ''
            runHook preConfigure
            export HOME="$TMPDIR"

            # The i686-w64-mingw32 cc-wrapper hook clobbers ambient $CC/$CXX; unset so
            # each sub-configure picks its own (native gcc, or mingw gcc via --host).
            unset CC CXX CPP

            # Accumulate the previous stage's toolchain into $out (writable), so this
            # stage installs alongside it into the one prefix the Makefile expects.
            mkdir -p "$out"
            ${lib.optionalString (prev != null) ''
              cp -a ${prev}/. "$out/"
              chmod -R u+w "$out"
            ''}

            # Writable source copies (libgloss/gcc generate files inside srcdir; the
            # flake inputs are read-only /nix/store paths). Plain cp -r keeps +x.
            cp -r ${tricore-gcc}           "$TMPDIR/src-gcc"
            cp -r ${tricore-binutils-gdb}  "$TMPDIR/src-binutils"
            cp -r ${tricore-newlib-cygwin} "$TMPDIR/src-newlib"
            chmod -R u+w "$TMPDIR/src-gcc" "$TMPDIR/src-binutils" "$TMPDIR/src-newlib"

            autoconf                       # generate ./configure from configure.ac
            mkdir -p build && cd build
            ../configure \
              --disable-debug \
              --prefix="$out" \
              --with-gcc-src="$TMPDIR/src-gcc" \
              --with-binutils-src="$TMPDIR/src-binutils" \
              --with-newlib-src="$TMPDIR/src-newlib"

            # Mark earlier stages done (their output is already in $out from prev), in
            # dependency order so timestamps never look stale to make.
            mkdir -p stamps
            ${lib.concatMapStringsSep "\n            " (s: ''touch "${s}"'') priorStamps}

            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            make -j"''${NIX_BUILD_CORES:-1}" ${lib.escapeShellArgs mathMakeFlags} ${target}
            runHook postBuild
          '';

          # The Makefile target already `make install`ed into $out; just sanity-check.
          installPhase = ''
            runHook preInstall
            [ -n "$(ls -A "$out/bin" 2>/dev/null)" ] || { echo "stage produced no $out/bin"; exit 1; }
            runHook postInstall
          '';
        };

      stageBinutils = mkStage {
        pname = "tricore-binutils";
        target = "stamps/build-binutils-tc";        # builds binutils-mcs then -tc
      };
      stageGcc1 = mkStage {
        pname = "tricore-gcc-stage1";
        target = "stamps/build-gcc-stage1";
        prev = stageBinutils;
        priorStamps = [ "stamps/build-binutils-mcs" "stamps/build-binutils-tc" ];
      };
      stageNewlib = mkStage {
        pname = "tricore-newlib";
        target = "stamps/build-newlib";
        prev = stageGcc1;
        priorStamps = [ "stamps/build-binutils-mcs" "stamps/build-binutils-tc" "stamps/build-gcc-stage1" ];
      };
      stageToolchain = mkStage {
        pname = "tricore-gcc-toolchain";
        target = "stamps/build-gcc-stage2";
        prev = stageNewlib;
        priorStamps = [ "stamps/build-binutils-mcs" "stamps/build-binutils-tc" "stamps/build-gcc-stage1" "stamps/build-newlib" ];
      };
    in
    {
      # The cross toolchain, built as a chain of per-stage derivations so a
      # restart/cache only redoes the stages that changed:
      #   binutils -> gcc-stage1 -> newlib -> gcc-stage2(default)
      # The intermediate stages are exposed too, so you can build/inspect one
      # (`nix build .#gcc-stage1`) and each caches independently.
      packages.${system} = {
        default = stageToolchain;
        binutils = stageBinutils;
        gcc-stage1 = stageGcc1;
        newlib = stageNewlib;
      };

      # `nix develop` -> a shell with the built toolchain ON PATH, so tricore-elf-gcc
      # works immediately. It builds packages.default once per machine (then instant
      # from /nix/store, or from a binary cache). There is no build-from-source shell:
      # `nix build`/`nix develop` IS the build.
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [ self.packages.${system}.default ];
        shellHook = ''
          echo ""
          echo "  tricore toolchain ready: $(tricore-elf-gcc --version | head -1)"
          echo "  example:  tricore-elf-gcc -O2 -c main.c -o main.o"
          echo ""
        '';
      };
    };
}
