# Publishing

## What it is
What leaves this repository for pub.dev and under what promise: the archive's contents,
the version, the changelog and the platforms claimed. Nothing here changes on a normal
day, and everything here fails for a stranger rather than locally.

## Governing decisions

**None.** No row in §12 decides what ships or how the version moves; the rules live in
`.pubignore` and in the changelog's shape, and were settled in the changes that made
them. Adjacent but not governing: the §12 row on `offset` becoming an `EdgeInsets`
records a **breaking** change and the release it went out in, which is a consequence of
this territory rather than a decision about it.

## Design model
The archive is `lib/`, `example/`, the README, the CHANGELOG and the licence. Excluded:
`/test/` — 368 KB against `lib`'s 240, and nobody consuming the package runs it —
together with `/docs/`, `CLAUDE.md`, `CONTEXT.md` and `AGENTS.md`.

**`.pubignore` replaces `.gitignore` for pub rather than adding to it**, so every rule
the two share is written twice. An exclusion added to `.gitignore` alone still ships.

This map is under `/docs/`, so it is **not published**. It is a repository artifact.

A published changelog entry is never rewritten, only superseded.

## Code

**None.** This territory is manifests and rules: `pubspec.yaml`, `.pubignore`,
`CHANGELOG.md`. There is no Dart in it, and the symbol check stands down.

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
- **No CI.** There is no `.github/`, so nothing enforces the formatter, the analyzer,
  the suite or `pub publish --dry-run` on a change. Every gate is run by hand.
- The platforms claimed are Windows, macOS and Linux; the package builds elsewhere and
  promises nothing there. Nothing checks that claim.
