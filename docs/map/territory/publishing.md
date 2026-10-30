# Publishing

## What it is
What leaves this repository for pub.dev and under what promise: the archive's contents,
the version, the changelog and the platforms claimed. Nothing here changes on a normal
day, and everything here fails for a stranger rather than locally.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the first dependency beyond Flutter,
  `flutter_smooth_wheel_scroll` from 0.1.4 (#107), and with it §2's promise dropped.

No other row decides what ships or how the version moves; those rules live in
`.pubignore` and in the changelog's shape, and were settled in the changes that made
them. Adjacent but not governing: the §12 row on `offset` becoming an `EdgeInsets`
records a **breaking** change and the release it went out in, which is a consequence of
this territory rather than a decision about it.

## Design model
The archive is `lib/`, `example/`, the README, the CHANGELOG and the licence. Excluded:
`/test/` — 368 KB against `lib`'s 240, and nobody consuming the package runs it —
together with `/docs/`, `CLAUDE.md`, `GLOSSARY.md` and `AGENTS.md`.

**`.pubignore` replaces `.gitignore` for pub rather than adding to it**, so every rule
the two share is written twice. An exclusion added to `.gitignore` alone still ships.

This map is under `/docs/`, so it is **not published**. It is a repository artifact.

Before a release, run `pub-ready`.

**One dependency beyond Flutter**, `flutter_smooth_wheel_scroll`, hosted, with its lower bound at
the first release carrying what this package relies on: 0.1.5, where a `WheelMotion` compares
by value (#118), after 0.1.4's layout correction under a glide. Its SDK floor sits below this
package's, so it moves no constraint; a consumer depending on it too resolves one copy. A new
lower bound there is a release here. The barrel re-exports its `WheelMotion` (#110), so a
breaking change to that type there is a breaking release here.

**Dependabot watches the constraints** (`.github/dependabot.yml`, #108). The root has no
committed lockfile, so `increase-if-necessary` opens a PR only when a release falls outside
the caret, and at `0.x` every minor release does. Such a PR is a lower-bound decision for
consumers rather than a chore, and for `flutter_smooth_wheel_scroll` it can be a breaking
release here too, so root PRs stay one per dependency: each is one release decision. The
example's PRs are grouped, because nothing ships from `example/`; its exact `flash` pin is
ignored, for the reason [Example harness](example-harness.md) gives. `.github/` is a dot
directory, which pub leaves out of the archive without a `.pubignore` rule.

## Code

**None.** This territory is manifests and rules: `pubspec.yaml`, `.pubignore`,
`CHANGELOG.md`, `.github/dependabot.yml`. There is no Dart in it, and the symbol check stands down.

## Reference behaviour

**None.** sonner is an npm package and its packaging says nothing about pub.dev's
archive rules. The relevant reference is pub.dev's own publishing documentation, which
has never been read into
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md).

## Cross-cutting invariants

**None.** Nothing here shares an assumption with another territory; what it constrains,
it constrains from outside.

## Blast radius
- [Configuration](configuration.md) — a change to a field's shape is a breaking release
  and obliges every consumer.
- [Example harness](example-harness.md) — `example/` ships, so its manifest is part of
  what a consumer resolves.

## Known holes / open
- **No CI.** `.github/` holds only the Dependabot configuration and no workflow, so
  nothing enforces the formatter, the analyzer, the suite or `pub publish --dry-run` on a
  change, a Dependabot PR included. Every gate is run by hand.
- The platforms claimed are Windows, macOS and Linux; the package builds elsewhere and
  promises nothing there. Nothing checks that claim.
