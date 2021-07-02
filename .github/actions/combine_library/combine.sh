#!/bin/bash

# Combine built static libraries into one library.
#
# The Microsoft Windows tools use different file extensions than the other tools:
# '.obj' as the object file extension, instead of '.o'
# '.lib' as the static library file extension, instead of '.a'
# '.dll' as the shared library file extension, instead of '.so'
#
# The Microsoft Windows tools have different names than the other tools:
# 'lib' as the librarian, instead of 'ar'. 'lib' must be found in path
#
# macOS and iOS uses 'libtool'.
#
# $1: The platform (win, mac, ios, linux)
# $2: The ninja build path
# $3: The output library name

function combine::static() {
  local platform="$1"
  local builddir="$2"
  local libname="libwebrtc_full"

  if [ -z "$platform" ]; then
	  echo "Must specify the plafrom (android, ios, linux, mac, win)"
    exit 255
  fi

  if [ -z "$builddir" ]; then
    echo "Must specify the build dir"
    exit 255
  fi

  if [ ! -d "$builddir" ]; then
    echo "Invalid build dir: $builddir"
    exit 255
  fi

  echo $libname
  pushd $builddir >/dev/null
    rm -f $libname.*

    # Find only the libraries we need
    if [ $platform = 'win' ]; then
      local whitelist="boringssl.dll.lib|protobuf_lite.dll.lib|webrtc\.lib|field_trial_default.lib|metrics_default.lib"
    else
      local whitelist="boringssl\.a|protobuf_lite\.a|webrtc\.a|field_trial_default\.a|metrics_default\.a"
    fi
    cat .ninja_log | tr '\t' '\n' | grep -E "^obj/" | grep -E $whitelist | sort -u >$libname.list

    # Combine all objects into one static library
    case $platform in
    win)
      lib.exe /OUT:$libname.lib @$libname.list
      ;;
    mac|ios)
      local libnames=""
      while read a; do
        libnames="$libnames $a"
      done <$libname.list
      libtool -static -o $libname.a $libnames
      ;;
    *)
      # Combine *.a static libraries
      echo "CREATE $libname.a" >$libname.ar
      while read a; do
        echo "ADDLIB $a" >>$libname.ar
      done <$libname.list
      echo "SAVE" >>$libname.ar
      echo "END" >>$libname.ar
      ar -M < $libname.ar
      ranlib $libname.a
      ;;
    esac
  popd >/dev/null
}

set -x

combine::static $@
