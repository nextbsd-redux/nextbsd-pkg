#!/bin/sh
# build.sh — runs INSIDE the FreeBSD VM (vmactions). Repackages the component
# `continuous` artifacts for ${ARCH} into one pkg(8) package each (named after
# the source repo), plus a NextBSD-world meta, into a FLAT repo (out/repo/).
#
# Arch-aware: amd64 gets all four packages; arm64 gets base + kernel + userland
# but NOT kernel-extensions (the kexts are amd64-only builds today). The
# packaging itself is cross-arch on the x86 VM — pkg create just tars already-built
# ELF with the ${ABI} label; it doesn't compile.
#
# Coherent-snapshot versioning (all share one version this run); UNSIGNED for now.
set -eux

pkg --version || pkg bootstrap -y

ARCH="${ARCH:-amd64}"
ABI="FreeBSD:15:${ARCH}"
VER="0.0.0.$(date -u +%Y%m%d%H%M%S)"

rm -rf stage out
mkdir -p out/repo

# mkpkg <name> <stagedir> <comment> <deps-ucl-or-empty>
mkpkg() {
  _name=$1; _root=$2; _comment=$3; _deps=$4
  cat > /tmp/+MANIFEST <<UCL
name: ${_name}
origin: nextbsd/${_name}
version: "${VER}"
comment: "${_comment}"
desc: "${_comment} — NextBSD ${ARCH} ${VER} snapshot."
maintainer: "dev@nextbsd.org"
www: "https://nextbsd.org"
abi: "${ABI}"
arch: "${ABI}"
prefix: "/"
UCL
  [ -n "${_deps}" ] && printf '%s\n' "${_deps}" >> /tmp/+MANIFEST
  ( cd "${_root}" && find . \( -type f -o -type l \) | sed 's#^\.##' ) | sort > /tmp/plist
  echo "=== ${_name}: $(wc -l < /tmp/plist) files ==="
  pkg create -M /tmp/+MANIFEST -p /tmp/plist -r "${_root}" -o out/repo
}

dep()  { printf 'deps: { %s: { origin: "nextbsd/%s", version: "%s" } }\n' "$1" "$1" "$VER"; }
dep2() { printf 'deps: { %s: { origin: "nextbsd/%s", version: "%s" }, %s: { origin: "nextbsd/%s", version: "%s" } }\n' "$1" "$1" "$VER" "$2" "$2" "$VER"; }

# --- 1. NextBSD-freebsd-compat (FreeBSD base: libc/libs, PAM, commands) ---
mkdir -p stage/compat
tar -C stage/compat -xzf "art/nextbsd-base-${ARCH}.tar.gz"
mkpkg NextBSD-freebsd-compat stage/compat "NextBSD FreeBSD-compatible base (libc, libs, PAM, login, command suites)" ""

# --- 2. NextBSD-kernel (just the stripped kernel binary from the obj tree) ---
mkdir -p stage/kernel/boot/kernel
KPATH=$(tar tzf "art/nextbsd-kernel-${ARCH}.tar.gz" | grep -E 'sys/NEXTBSD/kernel$' | head -1)
echo "kernel binary in artifact: ${KPATH:-NOT FOUND}"
[ -n "$KPATH" ] || { echo "ERROR: could not locate the kernel binary in the artifact" >&2; exit 1; }
mkdir -p /tmp/kx
tar -C /tmp/kx -xzf "art/nextbsd-kernel-${ARCH}.tar.gz" "$KPATH"
cp "/tmp/kx/$KPATH" stage/kernel/boot/kernel/kernel
chmod 555 stage/kernel/boot/kernel/kernel
mkpkg NextBSD-kernel stage/kernel "NextBSD kernel (FreeBSD 15 KBI, Mach + Darwin glue baked in)" ""

# --- 3. NextBSD-kernel-extensions (all kexts; amd64-only today) ---
HAVE_KEXTS=0
mkdir -p stage/kexts/System/Library/Extensions
for k in intelethernet-kext intelwifi-kext graphics-kexts; do
  [ -f "art/${k}.tar.gz" ] && tar -C stage/kexts/System/Library/Extensions -xzf "art/${k}.tar.gz"
done
if ls stage/kexts/System/Library/Extensions/*.kext >/dev/null 2>&1; then
  # Tarballs carry their build-runner uid; OSKext requires root:wheel + go-w.
  chown -R 0:0 stage/kexts
  find stage/kexts/System/Library/Extensions -maxdepth 1 -name '*.kext' -exec chmod -R go-w {} +
  echo "=== staged kexts ==="; ls -1 stage/kexts/System/Library/Extensions
  mkpkg NextBSD-kernel-extensions stage/kexts "NextBSD kernel extensions (IntelEthernet, IntelWiFi, graphics drm kexts + firmware)" "$(dep NextBSD-kernel)"
  HAVE_KEXTS=1
else
  echo "=== no kexts for ${ARCH} (arch-specific kexts not built) — skipping NextBSD-kernel-extensions ==="
fi

# --- 4. NextBSD-userland (Darwin Tier 0-2 runtime + daemons) ---
mkdir -p stage/userland
tar -C stage/userland -xzf "art/nextbsd-userland-${ARCH}.tar.gz"
mkpkg NextBSD-userland stage/userland "NextBSD Darwin/Mach userland (Mach, launchd, libdispatch, CoreFoundation, configd, IOKit + daemons)" "$(dep2 NextBSD-freebsd-compat NextBSD-kernel)"

# --- 5. NextBSD-world (meta: installs the whole OS for this arch) ---
mkdir -p stage/world
{
  echo "name: NextBSD-world"
  echo "origin: nextbsd/NextBSD-world"
  echo "version: \"${VER}\""
  echo "comment: \"NextBSD world meta-package (base + kernel + userland$([ "$HAVE_KEXTS" = 1 ] && echo ' + kernel-extensions'))\""
  echo "desc: \"Installs the complete NextBSD ${ARCH} OS snapshot ${VER}.\""
  echo "maintainer: \"dev@nextbsd.org\""
  echo "www: \"https://nextbsd.org\""
  echo "abi: \"${ABI}\""
  echo "arch: \"${ABI}\""
  echo "prefix: \"/\""
  echo "deps: {"
  echo "  NextBSD-freebsd-compat: { origin: \"nextbsd/NextBSD-freebsd-compat\", version: \"${VER}\" }"
  echo "  NextBSD-kernel: { origin: \"nextbsd/NextBSD-kernel\", version: \"${VER}\" }"
  echo "  NextBSD-userland: { origin: \"nextbsd/NextBSD-userland\", version: \"${VER}\" }"
  [ "$HAVE_KEXTS" = 1 ] && echo "  NextBSD-kernel-extensions: { origin: \"nextbsd/NextBSD-kernel-extensions\", version: \"${VER}\" }"
  echo "}"
} > /tmp/+MANIFEST
: > /tmp/plist
pkg create -M /tmp/+MANIFEST -p /tmp/plist -r stage/world -o out/repo

# --- catalog the flat repo ---
echo "=== packages (${ARCH}) ==="; ls -lh out/repo/*.pkg
pkg repo out/repo
echo "=== flat repo catalog ==="; ls -lh out/repo
