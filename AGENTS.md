# AGENTS.md

Guidance for AI coding agents (Claude Code and friends) working in this repo.
This repo declares the configuration for real machines — bad changes brick
boots, drop network, or lock users out. Treat it accordingly.

## Repo shape

- Flake-based NixOS config. Entry point: `flake.nix`.
- `hosts/<name>/` — per-machine modules (`system.nix`, `home.nix`, `hardware-configuration.nix`).
- `hosts/common/` — modules shared across every host. Changes here affect
  **all** machines, so prefer host-local changes unless the behavior is truly universal.
- `maskfile.md` is a symlink to `README.md`; `mask rebuild .#<host>` is the
  canonical rebuild entry point.

## Golden rules

1. **Never edit `hardware-configuration.nix`.** It is generator output.
2. **Never run `nixos-rebuild switch` without the user asking.** A switch mutates
   the running system. Suggest `nixos-rebuild build` or `dry-activate` for
   validation; let the user drive the switch.
3. **Never touch `.env`, secrets, or anything that looks like a credential.**
   `.env` is gitignored for a reason. Do not read, print, or stage it.
4. **Do not `git add -A` blindly.** The `mask rebuild` script does this
   intentionally so Nix can see new files; outside that flow, stage files by
   name so stray artifacts (shell history, caches, keys) don't get committed.
5. **Never commit without explicit user instruction.** Same for `git push`,
   branch deletions, force pushes, or any history rewrite.
6. **Never skip hooks** (`--no-verify`, `--no-gpg-sign`, etc.).
7. **Flake inputs are pinned** via `flake.lock`. Do not run `nix flake update`
   unless the user asks; bumping inputs is a cross-cutting change that deserves
   its own commit and review.

## DevSecOps practices

### Secrets & credentials
- No secrets in the Nix store. Anything written to a `.nix` file ends up
  world-readable in `/nix/store`. If something needs a secret, reach for
  `sops-nix` or `agenix` rather than inlining it.
- Treat `services.*.environmentVariables` and `environment.variables` as
  public. API keys, tokens, and passwords do not belong there.
- Prefer `services.openssh` key-based auth only (already set). Do not
  re-enable `PasswordAuthentication` or `PermitRootLogin`.

### Network & exposure
- Any new `networking.firewall.allowedTCPPorts` / `UDPPorts` entry is a
  deliberate attack-surface decision. Call it out explicitly in the PR/commit
  and prefer host-local over `hosts/common/`.
- New `services.*.openFirewall = true` likewise deserves a comment explaining
  why.
- Bind services to `127.0.0.1` / Tailscale / LAN addresses when possible, not
  `0.0.0.0`.

### Supply chain
- Flake inputs are code we execute as root at build time. Add a new input only
  when necessary; prefer well-known sources (`nixos`, `nix-community`,
  `nix-darwin`, upstream maintainer orgs). Note the source in the commit
  message when adding one.
- Prefer overlays and `nixpkgs` packages over `fetchFromGitHub` + custom
  derivations. If a custom derivation is unavoidable, pin a `rev` and a
  `hash` — never `master` with no hash.

### Privilege & isolation
- `trusted-users` grants effective root to the Nix daemon. Keep it minimal.
- `virtualisation.podman.dockerSocket.enable = true` (currently on in
  `common/system.nix`) is equivalent to root access for anyone in the podman
  group — do not broaden that group casually.
- Prefer rootless containers and user-scoped services where possible.

### Change hygiene
- One concern per commit. Do not bundle "enable service X" with "refactor
  module Y".
- Commit messages in this repo are short, imperative, lowercase (see
  `git log`). Match the style.
- Before proposing a rebuild, sanity-check with `nix flake check` or
  `nixos-rebuild build --flake .#<host>` and surface any evaluation errors.

### Reproducibility
- Do not introduce impurity (network fetches at eval, `builtins.currentTime`,
  unpinned fetchers). If a package needs to escape the sandbox, flag it.
- Keep host configs composable: use `imports` from `hosts/common/` rather than
  copy-pasting between hosts.

## When in doubt

Ask. The cost of a clarifying question is a few seconds; the cost of an
unwanted `switch` is a reinstall.
