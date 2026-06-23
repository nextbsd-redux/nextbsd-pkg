# nextbsd-pkg

Assembles versioned **pkg(8)** packages for NextBSD from the component repos'
`continuous` build artifacts and publishes a **flat pkg repository** to per-arch
GitHub Release tags (`continuous-amd64` / `continuous-arm64`).

## How it works

```
nextbsd-freebsd-compat ─┐
nextbsd-kernel ─────────┤  continuous artifacts
nextbsd-kernel-modules ─┤  (raw .tar.gz, per arch)
nextbsd-userland ───────┘
            │  repository_dispatch: userland-updated  (the single auto trigger)
            ▼
        nextbsd-pkg  ──(pkg create / pkg repo, inside a FreeBSD VM)──▶  flat repo
            │
            ▼  GitHub Release assets:  continuous-amd64 / continuous-arm64
        users:  pkg update && pkg upgrade        ISO builder:  pkg install NextBSD-world
```

- **pkg runs in a FreeBSD VM** (vmactions) — the Linux runner only downloads the
  (public) artifacts and uploads the Release assets.
- **Triggered by `userland-updated` only**, plus `workflow_dispatch` as a manual
  escape hatch for kernel/kext-only repackages. PRs build but never publish.
- **Flat repo on Release assets** (asset names can't contain `/`), one tag per arch.

## Consuming the repo

```
# /usr/local/etc/pkg/repos/NextBSD.conf
NextBSD: { url: "https://github.com/nextbsd-redux/nextbsd-pkg/releases/download/continuous-amd64", enabled: yes }
```

## Status

**Spike.** Currently validating one package (`NextBSD-darwin-runtime`), unsigned,
amd64, to prove the flat-repo-on-Releases mechanism end-to-end. The full package
split (see `docs/PLAN.json`), package signing, and arm64 land once it's proven.

The design (16-package split, dep pins, versioning, the pkg-in-VM ISO assembler
refactor) is in [`docs/PLAN.json`](docs/PLAN.json).
