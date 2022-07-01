#!/bin/sh

# Copyright 2014-present Viktor Szakats. See LICENSE.md

# shellcheck disable=SC3040
set -o xtrace -o errexit -o nounset; [ -n "${BASH:-}${ZSH_NAME:-}" ] && set -o pipefail

export _NAM
export _VER
export _OUT
export _BAS
export _DST

_NAM="$(basename "$0" | cut -f 1 -d '.')"
_VER="$1"

(
  cd "${_NAM}" || exit 0

  # Build

  rm -r -f pkg

  find . -name '*.o'   -delete
  find . -name '*.a'   -delete
  find . -name '*.lo'  -delete
  find . -name '*.la'  -delete
  find . -name '*.lai' -delete
  find . -name '*.Plo' -delete
  find . -name '*.pc'  -delete
  find . -name '*.dll' -delete
  find . -name '*.exe' -delete

  options="${_CONFIGURE_GLOBAL}"
  export CC="${_CC_GLOBAL}"
  export CFLAGS="${_CFLAGS_GLOBAL} -fno-ident -O3 -Wa,--noexecstack"
  export CPPFLAGS="${_CPPFLAGS_GLOBAL}"
  export LDFLAGS="${_LDFLAGS_GLOBAL}"
  export LIBS="${_LIBS_GLOBAL}"

  if [ "${_CC}" = 'clang' ]; then
    export RC="${_CCPREFIX}windres"
    export AR="${_CCPREFIX}ar"
    export NM="${_CCPREFIX}nm"
    export RANLIB="${_CCPREFIX}ranlib"
    CFLAGS="${CFLAGS} -Wno-inconsistent-dllimport"
  else
    CFLAGS="${CFLAGS} -Wno-attributes"
  fi

  _prefix='C:/Windows/libressl'
  _ssldir="ssl"

  # shellcheck disable=SC2086
  ./configure ${options} \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --disable-shared \
    --disable-tests \
    --silent \
    "--prefix=${_prefix}" \
    "--with-openssldir=${_prefix}/${_ssldir}"
# make clean > /dev/null
  # Ending slash required.
  make --jobs 2 install "DESTDIR=$(pwd)/pkg/" >/dev/null # 2>&1

  # DESTDIR= + --prefix=
  # LibreSSL does not strip the drive letter
  #   ./libressl/pkg/C:/Windows/libressl
  # Some tools (e.g CMake) become weird when colons appear in
  # a filename, so move results to a sane, standard path:

  _pkg="pkg${_PREFIX}"
  mkdir -p 'pkg/usr'  # Needs to be kept in sync with _PREFIX content
  mv "pkg/${_prefix}" "${_pkg}"

  # Delete .pc and .la files
  rm -r -f "${_pkg}"/lib/pkgconfig
  rm -f    "${_pkg}"/lib/*.la

  # List files created

  find "${_pkg}" | grep -a -v -F '/share/' | sort

  # Make steps for determinism

  readonly _ref='ChangeLog'

  "${_STRIP}" --preserve-dates --enable-deterministic-archives --strip-debug "${_pkg}"/lib/*.a

  touch -c -r "${_ref}" "${_pkg}"/lib/*.a
  touch -c -r "${_ref}" "${_pkg}"/include/openssl/*.h
  touch -c -r "${_ref}" "${_pkg}"/include/*.h

  # Tests

  # shellcheck disable=SC2043
  for bin in \
    "${_pkg}"/bin/openssl.exe \
  ; do
    file "${bin}"
    # Produce 'openssl version -a'-like output without executing the build:
    strings "${bin}" | grep -a -E '^(LibreSSL [0-9]|built on: |compiler: |platform: |[A-Z]+DIR: )' || true
  done

  # Create package

  _OUT="${_NAM}-${_VER}${_REVSUFFIX}${_PKGSUFFIX}"
  _BAS="${_NAM}-${_VER}${_PKGSUFFIX}"
  _DST="$(mktemp -d)/${_BAS}"

  mkdir -p "${_DST}/include/openssl"
  mkdir -p "${_DST}/lib"

  cp -f -p "${_pkg}"/lib/*.a             "${_DST}/lib"
  cp -f -p "${_pkg}"/include/openssl/*.h "${_DST}/include/openssl/"
  cp -f -p "${_pkg}"/include/*.h         "${_DST}/include/"
  cp -f -p ChangeLog                     "${_DST}/ChangeLog.txt"
  cp -f -p COPYING                       "${_DST}/COPYING.txt"
  cp -f -p README.md                     "${_DST}/"

  ../_pkg.sh "$(pwd)/${_ref}"
)
