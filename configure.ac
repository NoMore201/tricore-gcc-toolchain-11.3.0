#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_INIT([tricore-toolchain],[1.0])

# Checks for programs.
AC_PROG_YACC
AC_PROG_CC
AC_PROG_LEX

AC_PATH_PROG([BASH], [bash],
	[AC_MSG_ERROR([bash not found])])

# Native (x86_64-linux -> tricore-elf) build only; the Windows canadian-cross
# and qemu were removed, so the host is always empty.
AC_SUBST(configure_host,"")

AC_ARG_ENABLE(libstdcxx,
        [AS_HELP_STRING([--disable-libstdcxx],
		[do not build GCC libstdcxx-v3])],
        [],
        [enable_libstdcxx=yes]
        )

AS_IF([test "x$enable_libstdcxx" != xno],
	[AC_SUBST(configure_libstdcxx,"--enable-libstdcxx --enable-libstdcxx-debug-flags='-gdwarf-3 -g -O0 -D_GLIBCXX_ASSERTIONS' --disable-libstdcxx-pch")],
	[AC_SUBST(configure_libstdcxx,--disable-libstdcxx)])

AC_ARG_ENABLE(debug,
        [AS_HELP_STRING([--enable-debug],
		[build toolchain with debug symbols and avoid stripping final executables])],
        [],
        [enable_debug=yes]
        )

AS_IF([test "x$enable_debug" != xno],
	[AC_SUBST(configure_debug,"-g")],
	[AC_SUBST(configure_debug,"")])

AC_ARG_WITH(binutils-src,
	[AS_HELP_STRING([--with-binutils-src],[Set binutils source path, use builtin source by default])],
	[],
	[with_binutils_src=default]
	)

AS_IF([test "x$with_binutils_src" != xdefault],
	[AC_SUBST(with_binutils_src,$with_binutils_src)],
	[AC_SUBST(with_binutils_src,"\$(srcdir)/tricore-binutils-gdb")])

AC_ARG_WITH(newlib-src,
	[AS_HELP_STRING([--with-newlib-src],[Set newlib source path, use builtin source by default])],
	[],
	[with_newlib_src=default]
	)

AS_IF([test "x$with_newlib_src" != xdefault],
	[AC_SUBST(with_newlib_src,$with_newlib_src)],
	[AC_SUBST(with_newlib_src,"\$(srcdir)/tricore-newlib-cygwin")])

AC_ARG_WITH(gcc-src,
	[AS_HELP_STRING([--with-gcc-src],[Set gcc source path, use builtin source by default])],
	[],
	[with_gcc_src=default]
	)

AS_IF([test "x$with_gcc_src" != xdefault],
	[AC_SUBST(with_gcc_src,$with_gcc_src)],
	[AC_SUBST(with_gcc_src,"\$(srcdir)/tricore-gcc")])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
