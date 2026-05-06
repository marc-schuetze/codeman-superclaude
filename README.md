# codeman-superclaude

[Codeman][codeman] (mobile-first web UI for Claude Code) packaged with a small
patch that teaches it to discover the `sc|<path>` tmux sessions produced by
[scharc/superclaude][superclaude].

The two upstream projects are independent; this repo is only the *integration
glue*: a 50-LOC patch that extends Codeman's session-discovery, a Dockerfile
that builds it from a pinned commit, a compose file with the right host
mounts to drive the host's tmux server, and a Forgejo Actions workflow that
publishes the image.

## What it does

- Codeman's `tmux-manager.ts` ships with `codeman-*` and `claudeman-*` as the
  only allowed session-name prefixes. The patch adds a third pattern,
  `^sc\|/<abs-path>(?:-\d+)?$`, so superclaude's sticky-per-cwd sessions
  show up in the web UI.
- `parsePaneList` is switched from `indexOf('|')` to a regex anchored on the
  rightmost `|<digits>` block, so session names that themselves contain `|`
  parse correctly.
- The upstream installer's `alias sc='tmux-chooser'` line is skipped to avoid
  clobbering the `sc` binary that comes with superclaude.

Everything else (web UI, respawn controller, subagent watcher, zerolag input
overlay, QR auth) is unmodified upstream.

## Layout

```
.
├── CODEMAN_COMMIT                         pinned upstream short SHA
├── patches/
│   └── 0001-discover-superclaude-sessions.patch
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

The patch is tiny and isolated (one regex addition, one prefix check, one
parser swap). Carrying a long-lived fork costs more than re-applying ~50 lines
on each upstream bump. When upstream merges a configurable discovery hook,
this repo collapses to just the Docker + Traefik glue — `patches/` becomes
empty.

[codeman]: https://github.com/Ark0N/Codeman
[superclaude]: https://github.com/scharc/superclaude
