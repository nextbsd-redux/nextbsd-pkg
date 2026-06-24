#!/bin/sh
# verify.sh — runs INSIDE a fresh FreeBSD VM. Points pkg at the just-published
# flat repo (continuous-${ARCH} Release assets) and confirms the package set is
# queryable and that NextBSD-world resolves the full dependency graph.
#
# The VM is x86 but the resolution is metadata-only (dry-run -n), so it validates
# arm64 catalogs too (pkg -o ABI=FreeBSD:15:arm64 resolves deps without extracting).
set -eux

pkg --version || pkg bootstrap -y

ARCH="${ARCH:-amd64}"
# pkg's ABI uses 'aarch64' for 64-bit ARM; the release tag / artifacts use 'arm64'.
case "$ARCH" in arm64) ABIARCH=aarch64 ;; *) ABIARCH="$ARCH" ;; esac
BASE="https://github.com/nextbsd-redux/nextbsd-pkg/releases/download/continuous-${ARCH}"

mkdir -p /usr/local/etc/pkg/repos
printf 'FreeBSD: { enabled: no }\n' > /usr/local/etc/pkg/repos/FreeBSD.conf
cat > /usr/local/etc/pkg/repos/NextBSD.conf <<CONF
NextBSD: {
  url: "${BASE}",
  enabled: yes,
  signature_type: none,
}
CONF

PKG="pkg -o ABI=FreeBSD:15:${ABIARCH} -o IGNORE_OSVERSION=yes"

echo "=== pkg update (fetch catalog from the flat Release repo, ${ARCH}) ==="
$PKG update -f

echo "=== every NextBSD package in the ${ARCH} catalog ==="
$PKG search -r NextBSD NextBSD

echo "=== dry-run install of the whole OS (NextBSD-world resolves the graph) ==="
$PKG install -n -y NextBSD-world

echo "OK: ${ARCH} flat pkg repo readable; NextBSD-world resolves the dependency graph"
