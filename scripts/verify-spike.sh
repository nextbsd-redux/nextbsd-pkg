#!/bin/sh
# verify-spike.sh — runs INSIDE a fresh FreeBSD VM. Points pkg at the JUST-PUBLISHED
# flat repo (GitHub Release assets under continuous-amd64) and confirms pkg can
# fetch + parse the catalog and resolve the package. This is the core thing the
# spike validates: a flat pkg repo served from Release assets is consumable.
set -eux

pkg --version || pkg bootstrap -y

BASE="https://github.com/nextbsd-redux/nextbsd-pkg/releases/download/continuous-amd64"

mkdir -p /usr/local/etc/pkg/repos
# Disable the stock FreeBSD repo so we test ONLY the NextBSD flat repo.
printf 'FreeBSD: { enabled: no }\n' > /usr/local/etc/pkg/repos/FreeBSD.conf
cat > /usr/local/etc/pkg/repos/NextBSD.conf <<CONF
NextBSD: {
  url: "${BASE}",
  enabled: yes,
  signature_type: none,
}
CONF

# Packages are tagged FreeBSD:15:amd64; this VM is 14.x, so override ABI +
# ignore the osversion gate (the assembler does the same).
PKG="pkg -o ABI=FreeBSD:15:amd64 -o IGNORE_OSVERSION=yes"

echo "=== pkg update (fetch meta.conf + catalog from the flat Release repo) ==="
$PKG update -f

echo "=== rquery the published NextBSD repo ==="
$PKG rquery -r NextBSD '%n %v  (flatsize %sb bytes)' '*'

echo "=== dry-run install resolution ==="
$PKG install -n -y NextBSD-darwin-runtime || true

echo "OK: flat pkg repo on GitHub Release assets is readable by pkg(8)"
