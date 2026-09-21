## Agent skills

| When | Read |
|---|---|
| Creating, reading, labelling or closing an issue or PR (GitHub, via `gh`) | `docs/agents/issue-tracker.md` |
| A skill names a triage role | `docs/agents/triage-labels.md` |
| Exploring the code, or naming a domain concept | `docs/agents/domain.md` |
| **Before** committing to a design: what else moves, and what decided this | [`docs/map/`](docs/map/README.md) — open the territory you are changing, follow its `## Blast radius` as a checklist, and read `## Governing decisions` for why. An empty section is the answer |

## Where a file goes

```
lib/just_sonner.dart          the only export barrel; no other .dart at lib/'s root
lib/src/**                    private; a consumer imports the barrel and nothing else
lib/src/look/*.dart           may import package:flutter/material.dart
lib/src/config.dart           may too — it holds default widgets
lib/src/*.dart                otherwise must not; package:flutter/widgets.dart is the ceiling
test/*_test.dart              flat, named <subject>_test.dart
example/                      its own package; nothing under lib/ imports it
docs/                         not published (.pubignore)
```

A file belongs in `lib/src/look/` when it **draws** a part of the deck that needs a
theme role. `config.dart` is the one exception and stays out: it imports `material` for
a default widget (`CircularProgressIndicator`) and draws nothing itself, so putting it
under a directory named for drawing would make the name lie.

Still undecided, and deliberately left so: whether the fifteen engine files split
further, how `test/` is laid out now that one file is three quarters of the suite, and
whether this repo wants CI.

## Comments

A comment says what the code is. Why it is this way, what it deliberately leaves out,
the trap and the measured value go to the territory note under `docs/map/`; history
goes to the commit message.
