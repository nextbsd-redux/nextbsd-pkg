#!/bin/sh
# build-spike.sh — runs INSIDE the FreeBSD VM (vmactions). Spike: package a
# single component (the Darwin runtime) into one pkg(8) package and generate a
# FLAT repo catalog. Proves pkg create + pkg repo over a pre-built file tree.
# Output: out/repo/{*.pkg, meta.conf, packagesite.pkg, data.pkg} (flat).
set -eux

pkg --version || pkg bootstrap -y

ARCH=amd64
# Spike ABI: FreeBSD:15:amd64 (the auto-detected ABI of a NextBSD/15 image, since
# the ELF brand is unchanged). The distinct nextbsd:15 namespace is a deferred
# maintainer decision — orthogonal to validating the flat-repo mechanism.
ABI="FreeBSD:15:amd64"
VER="0.0.0.$(date -u +%Y%m%d%H%M%S)"

rm -rf stage out
mkdir -p stage/darwin out/repo
tar -C stage/darwin -xzf "art/nextbsd-userland-${ARCH}.tar.gz"

# Package metadata (no file list here — the plist below provides it; pkg reads
# each file from -r rootdir and computes its checksum).
cat > stage/+MANIFEST <<UCL
name: NextBSD-darwin-runtime
origin: nextbsd/darwin-runtime
version: "${VER}"
comment: "NextBSD Darwin/Mach system runtime"
desc: "Mach, launchd, libdispatch, libxpc, CoreFoundation, configd, IOKit and the Tier 0-2 Darwin system daemons cross-built for NextBSD."
maintainer: "dev@nextbsd.org"
www: "https://nextbsd.org"
abi: "${ABI}"
arch: "${ABI}"
prefix: "/"
UCL

# Build the plist (absolute paths) from the staged tree.
( cd stage/darwin && find . \( -type f -o -type l \) | sed 's#^\.##' ) | sort > stage/pkg-plist
echo "=== plist: $(wc -l < stage/pkg-plist) entries ==="
head -5 stage/pkg-plist

# Create the package (flat into out/repo), then catalog the dir.
pkg create -M stage/+MANIFEST -p stage/pkg-plist -r stage/darwin -o out/repo
echo "=== package(s) ==="
ls -lh out/repo

pkg repo out/repo
echo "=== flat repo catalog ==="
ls -lh out/repo
