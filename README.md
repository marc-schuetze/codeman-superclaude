# codeman-superclaude

[Codeman][codeman] (mobile-first web UI for Claude Code) packaged with a small
patch series that teaches it to discover the `sc|<path>` tmux sessions
produced by [scharc/superclaude][superclaude] and to treat them as
externally-managed.

The two upstream projects are independent; this repo is only the *integration
glue*: a series of patches that make Codeman and superclaude share one tmux
namespace (plus a couple of mobile-UI niceties), a Dockerfile that builds it
from a pinned commit, a compose file with the right host mounts to drive the
host's tmux server, and a Forgejo Actions workflow that publishes the image.

## What it does

Session-namespace integration (`sc|<abs-path>` sessions shared between the
`sc` picker/terminal and the Codeman web UI):

- **0001 discover** — Codeman's `tmux-manager.ts` only allows `codeman-*` /
  `claudeman-*` prefixes. Adds `^sc\|/<abs-path>(?:-\d+)?$`, and switches
  `parsePaneList` from `indexOf('|')` to a regex anchored on the rightmost
  `|<digits>` block so names containing `|` parse. Skips the installer's
  `alias sc='tmux-chooser'` so it doesn't clobber superclaude's `sc`.
- **0002 create** — Codeman *creates* new sessions with the same
  `sc|<abs-path>[-N]` naming when the working dir fits the slug, so picker,
  web UI and terminal share one namespace.
- **0003 reconcile-wrap** — discovered sessions get wrapped in server-side
  `Session` objects (else the monitor panel shows them `UNKNOWN`); broadcasts
  `SessionCreated` so tabs appear without a refresh.
- **0004 mouse-skip** — marks discovered sessions `discovered: true` and skips
  them in the mouse-mode sync (they may be terminal-attached).
- **0006 slug-rewrite** — mirror superclaude's `slug()`: tmux rewrites `.`/`:`
  to `_` in session names, so create must too (else the stored name and the
  target diverge → the session can't be driven). Discovery reads the real
  `#{pane_current_path}` instead of the lossy reverse-slug.
- **0007 shell-escape** — shell-escape `CODEMAN_MUX_NAME` in the launch env
  exports: `sc|<path>` contains a literal `|` that was parsed as a pipe,
  running the working dir as a command ("Is a directory", exit 126) — every
  web-created session died on spawn.
- **0009 periodic-reconcile** — reconcile on a timer so externally-created
  (`sc`) sessions are auto-discovered without a manual reconcile / restart.
- **0010 dead-pane reap** — reap sessions whose pane exited (remain-on-exit
  keeps a dead pane) so zombies don't pile up; skips auto-resume / respawn.

Mobile UI (upstream is unopinionated here):

- **0005 session drawer** — slide-in left drawer (hamburger) listing sessions
  vertically on phones; reuses `#sessionTabs`, reparented out of `<header>`.
- **0008 drawer close-[x]** — show the per-row close-[x] on every drawer row
  (not just the active tab) and dismiss the drawer to reveal the confirm modal.

Everything else (respawn controller, subagent watcher, zerolag input overlay,
QR auth) is unmodified upstream.

## Layout

```
.
├── CODEMAN_COMMIT                         pinned upstream full SHA
├── patches/                               0001..0010 (git format-patch series)
├── docker/
│   ├── Dockerfile                         multi-stage; clones + patches + builds
│   ├── compose.yml                        deployment compose (zkm-infra desktop)
│   └── .env.example                       host UID, paths, hostname
├── traefik/
│   └── code-laptop.yml.example            hetzner-edge file router for laptop
├── scripts/
│   ├── make-patch.sh                      regenerate patches from /x/repos/Codeman
│   └── upgrade.sh                         pull upstream, rebase, rebuild
├── .forgejo/workflows/build.yml           Forgejo Actions: build + push image
└── README.md
```

## Image

Built by Forgejo Actions on push to `main`, published to:

```
git.schuetze.io/marc/codeman-superclaude:latest
git.schuetze.io/marc/codeman-superclaude:<commit-sha>
git.schuetze.io/marc/codeman-superclaude:codeman-<upstream-sha>
```

## Deploy on the desktop (zkm-infra)

```bash
mkdir -p /opt/docker/codeman
cp docker/compose.yml docker/.env.example /opt/docker/codeman/
mv /opt/docker/codeman/.env.example /opt/docker/codeman/.env
$EDITOR /opt/docker/codeman/.env       # set CODEMAN_HOST, optionally CODEMAN_PASSWORD
cd /opt/docker/codeman && docker compose up -d
```

Public access is wired automatically by the existing `zkm-catch` wildcard at
hetzner-edge → desktop Traefik, which dispatches `code.scharc.de` (or whatever
`CODEMAN_HOST` is) by Docker label. `protected@file` is applied at the edge.

## Deploy laptop access

The laptop has no Traefik of its own — hetzner-edge reaches it directly over
Tailscale. Drop `traefik/code-laptop.yml.example` into the edge's
`/opt/data/traefik/dynamic/` after replacing the placeholder Tailscale IP.

When the laptop is offline the route returns 502; that's expected.

## Upgrading upstream

```bash
./scripts/upgrade.sh                   # rebases patch onto latest origin/master
git -C . diff                          # review patch + CODEMAN_COMMIT bump
git add patches/ CODEMAN_COMMIT
git commit -m "chore: bump codeman to <sha>"
git push                               # Forgejo Actions builds the new image
```

If `upgrade.sh` reports a rebase conflict, the patch needs updating against
upstream's latest changes — or it's time to push the patch upstream as a
`CODEMAN_DISCOVER_PREFIXES` config option PR.

## Why an addon repo and not a fork

The patch series is small and isolated. Carrying a long-lived fork costs more
than re-applying a few hundred lines on each upstream bump. When upstream
merges a configurable discovery hook (and accepts the discovered-session
flag for non-clobbering tmux config), this repo collapses to just the
Docker + Traefik glue — `patches/` becomes empty.

[codeman]: https://github.com/Ark0N/Codeman
[superclaude]: https://github.com/scharc/superclaude
