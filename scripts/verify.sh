#!/bin/sh
# verify.sh — runs INSIDE a fresh FreeBSD VM. Points pkg at the just-published
# flat repo (continuous-amd64 Release assets) and confirms the whole package set
# is queryable and that NextBSD-world resolves the full dependency graph.
set -eux

pkg --version || pkg bootstrap -y

BASE="https://github.com/nextbsd-redux/nextbsd-pkg/releases/download/continuous-amd64"

mkdir -p /usr/local/etc/pkg/repos
printf 'FreeBSD: { enabled: no }\n' > /usr/local/etc/pkg/repos/FreeBSD.conf
cat > /usr/local/etc/pkg/repos/NextBSD.conf <<CONF
NextBSD: {
  url: "${BASE}",
  enabled: yes,
  signature_type: none,
}
CONF

PKG="pkg -o ABI=FreeBSD:15:amd64 -o IGNORE_OSVERSION=yes"

echo "=== pkg update (fetch catalog from the flat Release repo) ==="
$PKG update -f

echo "=== every NextBSD package in the catalog ==="
$PKG search -r NextBSD NextBSD

echo "=== dry-run install of the whole OS (NextBSD-world resolves the graph) ==="
$PKG install -n -y NextBSD-world

echo "OK: flat pkg repo readable; NextBSD-world resolves base + kernel + kernel-extensions + userland"
