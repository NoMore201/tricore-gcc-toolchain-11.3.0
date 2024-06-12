FROM debian:bookworm-slim

ARG WIN32_PREFIX=/tricore-win32
ARG LINUX_PREFIX=/tricore-linux
ARG WIN32_HOST_ARCH=x86_64-w64-mingw32
ARG LINUX_HOST_ARCH=x86_64-linux-gnu
ARG GMP_VERSION=6.3.0
ARG MINGW_VERSION=11.0.1
ARG MPC_VERSION=1.3.1
ARG MPFR_VERSION=4.2.1
ARG CFLAGS="-Os"
ARG CXXFLAGS="-Os"
ARG LDFLAGS="-static -s"
ARG TRICORE_GCC_VERSION=11.3.1

WORKDIR /

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
    build-essential \
    curl \
    gcc-mingw-w64 \
    g++-mingw-w64 \
    libgmp-dev \
    libmpc-dev \
    libmpfr-dev \
    m4 \
    zip \
    flex \
    bison \
    texinfo

RUN curl --insecure --location --remote-name-all --remote-header-name \
    https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.xz \
    https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.gz \
    https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.xz

RUN tar xJf gmp-$GMP_VERSION.tar.xz \
    && tar xzf mpc-$MPC_VERSION.tar.gz \
    && tar xJf mpfr-$MPFR_VERSION.tar.xz


#################################################################
#
# Initialize Tricore folders
#
#################################################################

WORKDIR /tricore-src
COPY tricore-gcc /tricore-src/tricore-gcc/
COPY tricore-binutils-gdb /tricore-src/tricore-binutils-gdb/
COPY tricore-newlib-cygwin /tricore-src/tricore-newlib-cygwin/


#################################################################
#
# Build Tricore cross-compiler for Linux
#
#################################################################

WORKDIR /tricore-build/binutils-mcs-linux
RUN /tricore-src/tricore-binutils-gdb/configure \
    LDFLAGS="$LDFLAGS" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    --target=mcs-elf \
    --host=$LINUX_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
    --program-prefix=mcs-elf- \
    --disable-threads \
    --disable-nls \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --disable-sim \
    --disable-gdb \
    --disable-newlib \
    --disable-libgloss \
    --disable-test-suite \
    --enable-checking=release \
    --with-gnu-ld \
    --with-gnu-as \
    --prefix=$LINUX_PREFIX \
    --disable-werror && \
    make MAKEINFO=true -j$(nproc) && \
    make MAKEINFO=true -j$(nproc) install

WORKDIR /tricore-build/binutils-linux
RUN /tricore-src/tricore-binutils-gdb/configure \
    LDFLAGS="$LDFLAGS" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    --target=tricore-elf \
    --host=$LINUX_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
    --enable-targets=mcs-elf \
    --program-prefix=tricore-elf- \
    --disable-threads \
    --disable-nls \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --disable-sim \
    --disable-gdb \
    --disable-newlib \
    --disable-libgloss \
    --disable-test-suite \
    --enable-checking=release \
    --with-gnu-ld \
    --with-gnu-as \
    --prefix=$LINUX_PREFIX \
    --disable-werror && \
    make MAKEINFO=true -j$(nproc) && \
    make MAKEINFO=true -j$(nproc) install


WORKDIR /tricore-build/gcc-stage1-linux
RUN /tricore-src/tricore-gcc/configure \
    LDFLAGS="$LDFLAGS" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    CFLAGS_FOR_TARGET="$CFLAGS" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS" \
    --target=tricore-elf \
    --host=$LINUX_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
	--enable-lib32 \
	--disable-lib64 \
    --prefix=$LINUX_PREFIX \
    --enable-languages=c,c++ \
    --enable-libstdcxx-debug-flags="-gdwarf-3 -g -O0 -D_GLIBCXX_ASSERTIONS" \
    --enable-c99 \
    --enable-long-long \
    --enable-checking \
    --disable-nls \
    --enable-static \
    --disable-threads \
    --disable-shared \
    --with-headers=yes \
    --with-newlib=yes \
    --enable-mingw-wildcard \
    --disable-libstdcxx-pch \
    --enable-newlib-elix-level=3 \
    --enable-newlib-io-long-long \
    --disable-newlib-supplied-syscalls \
    --disable-libssp \
    --disable-test-suite \
    && make MAKEINFO=true -j$(nproc) all-gcc \
    && make MAKEINFO=true install-gcc

WORKDIR /tricore-build/newlib-linux
RUN /tricore-src/tricore-newlib-cygwin/configure \
    CC_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-gcc \
    CXX_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-c++ \
    GCC_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-gcc \
    AR_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-ar \
    AS_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-as \
    LD_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-ld \
    NM_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-nm \
    OBJDUMP_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-objdump \
    RANLIB_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-ranlib \
    STRIP_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-strip \
    READELF_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-readelf \
    CFLAGS_FOR_TARGET="$CFLAGS -ffunction-sections -mfast-div -fno-common" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS -ffunction-sections -mfast-div -fno-common" \
	--target=tricore-elf \
	--host=i686-w64-mingw32 \
	--build=i686-pc-mingw32 \
    --prefix=$LINUX_PREFIX \
    && make -j$(nproc) LDFLAGS="-static" \
    && make install

WORKDIR /tricore-build/gcc-stage2-linux
RUN /tricore-src/tricore-gcc/configure \
    LDFLAGS="$LDFLAGS" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    CFLAGS_FOR_TARGET="$CFLAGS" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS" \
    --target=tricore-elf \
    --host=$LINUX_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
    --enable-lib32 \
    --disable-lib64 \
    --prefix=$LINUX_PREFIX \
    --enable-languages=c,c++ \
    --enable-libstdcxx-debug-flags="-gdwarf-3 -g -O0 -D_GLIBCXX_ASSERTIONS" \
    --enable-c99 \
    --enable-long-long \
    --enable-checking \
    --disable-nls \
    --enable-static \
    --disable-threads \
    --disable-shared \
    --with-headers=yes \
    --with-newlib=yes \
	--with-gnu-ld \
	--with-gnu-as \
    --enable-mingw-wildcard \
    --disable-libstdcxx-pch \
    --enable-newlib-elix-level=3 \
    --enable-newlib-io-long-long \
    --disable-newlib-supplied-syscalls \
    --disable-libssp \
    --disable-test-suite \
    && make MAKEINFO=true -j$(nproc) \
    && make MAKEINFO=true install

#################################################################
#
# Build Windows host dependencies
#
#################################################################

WORKDIR /gmp
RUN /gmp-$GMP_VERSION/configure \
    --prefix=/bootstrap \
    --host=$WIN32_HOST_ARCH \
    --disable-assembly \
    --enable-static \
    --disable-shared \
    CFLAGS="$CFLAGS"\
    CXXFLAGS="$CXXFLAGS"\
    LDFLAGS="$LDFLAGS" \
    && make -j$(nproc) \
    && make install

WORKDIR /mpfr
RUN /mpfr-$MPFR_VERSION/configure \
    --prefix=/bootstrap \
    --host=$WIN32_HOST_ARCH \
    --with-gmp-include=/bootstrap/include \
    --with-gmp-lib=/bootstrap/lib \
    --enable-static \
    --disable-shared \
    CFLAGS="$CFLAGS"\
    LDFLAGS="$LDFLAGS" \
    && make -j$(nproc) \
    && make install

WORKDIR /mpc
RUN /mpc-$MPC_VERSION/configure \
    --prefix=/bootstrap \
    --host=$WIN32_HOST_ARCH \
    --with-gmp-include=/bootstrap/include \
    --with-gmp-lib=/bootstrap/lib \
    --with-mpfr-include=/bootstrap/include \
    --with-mpfr-lib=/bootstrap/lib \
    --enable-static \
    --disable-shared \
    CFLAGS="$CFLAGS"\
    LDFLAGS="$LDFLAGS" \
    && make -j$(nproc) \
    && make install


#################################################################
#
# Build Tricore cross-compiler for Windows using MinGW cross-compiler
#
#################################################################

WORKDIR /tricore-build/binutils-mcs-win
RUN /tricore-src/tricore-binutils-gdb/configure \
    LDFLAGS="$LDFLAGS" \
    --host=$WIN32_HOST_ARCH \
    --build=${LINUX_HOST_ARCH} \
    --target=mcs-elf \
    --program-prefix=mcs-elf- \
    --disable-threads \
    --disable-nls \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --disable-sim \
    --disable-gdb \
    --disable-newlib \
    --disable-libgloss \
    --disable-test-suite \
    --enable-checking=release \
    --with-gnu-ld \
    --with-gnu-as \
    --prefix=$WIN32_PREFIX \
    --disable-werror && \
    make MAKEINFO=true -j$(nproc) && \
    make MAKEINFO=true -j$(nproc) install

WORKDIR /tricore-build/binutils-win
RUN /tricore-src/tricore-binutils-gdb/configure \
    LDFLAGS="$LDFLAGS" \
    --host=$WIN32_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
    --target=tricore-elf \
	--enable-targets=mcs-elf \
    --program-prefix=tricore-elf- \
    --disable-threads \
    --disable-nls \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --disable-sim \
    --disable-gdb \
    --disable-newlib \
    --disable-libgloss \
    --disable-test-suite \
    --enable-checking=release \
    --with-gnu-ld \
    --with-gnu-as \
    --prefix=$WIN32_PREFIX \
    --disable-werror && \
    make MAKEINFO=true -j$(nproc) && \
    make MAKEINFO=true -j$(nproc) install

ENV PATH="/tricore-linux/bin:$PATH"

WORKDIR /tricore-build/gcc-stage1-win
COPY docker/0001* /tricore-src/tricore-gcc/
RUN cat /tricore-src/tricore-gcc/0001*.patch | patch -d/tricore-src/tricore-gcc/ -p1 \
    && /tricore-src/tricore-gcc/configure \
    LDFLAGS="$LDFLAGS" \
    CFLAGS_FOR_TARGET="$CFLAGS" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS" \
    --target=tricore-elf \
    --host=$WIN32_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
    --enable-lib32 \
    --disable-lib64 \
    --prefix=$WIN32_PREFIX \
    --enable-languages=c,c++ \
    --enable-libstdcxx-debug-flags="-gdwarf-3 -g -O0 -D_GLIBCXX_ASSERTIONS" \
    --enable-c99 \
    --enable-long-long \
    --enable-checking \
    --disable-nls \
    --enable-static \
    --disable-threads \
    --disable-shared \
    --with-headers=yes \
    --with-newlib=yes \
    --with-gmp=/bootstrap \
    --with-mpfr=/bootstrap \
    --with-mpc=/bootstrap \
    --enable-mingw-wildcard \
    --disable-libstdcxx-pch \
    --enable-newlib-elix-level=3 \
    --enable-newlib-io-long-long \
    --disable-newlib-supplied-syscalls \
    --disable-libssp \
    --disable-test-suite \
    && make MAKEINFO=true -j$(nproc) all-gcc \
    && make MAKEINFO=true install-gcc

WORKDIR /tricore-build/newlib-mingw
RUN /tricore-src/tricore-newlib-cygwin/configure \
    CC_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-gcc \
    CXX_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-c++ \
    GCC_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-gcc \
    AR_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-ar \
    AS_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-as \
    LD_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-ld \
    NM_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-nm \
    OBJDUMP_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-objdump \
    RANLIB_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-ranlib \
    STRIP_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-strip \
    READELF_FOR_TARGET=$LINUX_PREFIX/bin/tricore-elf-readelf \
    CFLAGS_FOR_TARGET="$CFLAGS -ffunction-sections -mfast-div -fno-common" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS -ffunction-sections -mfast-div -fno-common" \
    --target=tricore-elf \
    --host=i686-w64-mingw32 \
    --build=i686-pc-mingw32 \
    --prefix=$WIN32_PREFIX \
    && make -j$(nproc) LDFLAGS="-static" \
    && make install

WORKDIR /tricore-build/gcc-stage2-mingw
RUN /tricore-src/tricore-gcc/configure \
    LDFLAGS="$LDFLAGS" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    CFLAGS_FOR_TARGET="$CFLAGS" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS" \
    --target=tricore-elf \
    --host=$WIN32_HOST_ARCH \
    --build=$LINUX_HOST_ARCH \
    --enable-lib32 \
    --disable-lib64 \
    --prefix=$WIN32_PREFIX \
    --enable-languages=c,c++ \
    --enable-libstdcxx-debug-flags="-gdwarf-3 -g -O0 -D_GLIBCXX_ASSERTIONS" \
    --enable-c99 \
    --enable-long-long \
    --enable-checking \
    --disable-nls \
    --enable-static \
    --disable-threads \
    --disable-shared \
    --with-headers=yes \
    --with-newlib=yes \
    --with-gnu-ld \
    --with-gnu-as \
    --with-gmp=/bootstrap \
    --with-mpfr=/bootstrap \
    --with-mpc=/bootstrap \
    --enable-mingw-wildcard \
    --disable-libstdcxx-pch \
    --enable-newlib-elix-level=3 \
    --enable-newlib-io-long-long \
    --disable-newlib-supplied-syscalls \
    --disable-libssp \
    --disable-test-suite \
    && make MAKEINFO=true -j$(nproc) \
    && make MAKEINFO=true install

ENV WIN32_PREFIX=${WIN32_PREFIX}
ENV LINUX_PREFIX=${LINUX_PREFIX}
ENV TRICORE_GCC_VERSION=${TRICORE_GCC_VERSION}

WORKDIR /output
VOLUME /output

CMD zip -q9Xr /output/tricore-elf-gcc-$TRICORE_GCC_VERSION-win32.zip $WIN32_PREFIX && \
    zip -q9Xr /output/tricore-elf-gcc-$TRICORE_GCC_VERSION-linux.zip $LINUX_PREFIX