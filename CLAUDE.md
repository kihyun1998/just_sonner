## Agent skills

| When | Read |
|---|---|
| Creating, reading, labelling or closing an issue or PR (GitHub, via `gh`) | `docs/agents/issue-tracker.md` |
| A skill names a triage role | `docs/agents/triage-labels.md` |
| Exploring the code, or naming a domain concept | `docs/agents/domain.md` |
| **Before** committing to a design: what else moves, and what decided this | [`docs/map/`](docs/map/README.md) — the territory you are changing |

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
theme role. `config.dart` imports `material` only for a default widget
(`CircularProgressIndicator`) and draws nothing, so it stays out.

Still undecided, and deliberately left so: whether the engine files under `lib/src/`
split further, how `test/` is laid out (`wc -c test/*_test.dart`), and whether this repo
wants CI.

## Comments

A comment says what the code is. Why it is this way, what it deliberately leaves out,
the trap and the measured value go to the territory note under `docs/map/`; history
goes to the commit message.
