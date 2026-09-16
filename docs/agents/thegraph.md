# thegraph build

## What this project is

A Flutter stacking-toast package. `docs/spec.md` is the contract;
where a reference disagrees with it, the spec wins.

**Matching sonner is not a goal.** It is read because it is a working implementation of the same
idea, so it answers "what happens when…" cheaply. It does not set this package's values.

## References

| Source | Informs | Reached by | Binding |
|---|---|---|---|
| emilkowalski/sonner | how it works | `research/sonner-values.md`, on the `research/sonner-values` branch — every value the spec cites, checked against one pinned commit and line-linked. Anything it does not carry: sonner's source tree, raw | example — where the spec is silent, follow sonner and record the divergence |
| flash (`FlashBar`, `FlashController`) | how it works | its source tree — raw | binding for the §1 adapter only |
| Flutter SDK (Overlay, animation) | how it works | local SDK source — raw | binding |
| The example app (`example/`) | how it looks and moves | run it: `cd example && flutter run -d windows` | binding for §9's colours and dimensions, and for any question of the form "does this read right" |

The research file is pinned to one commit; say which path you used when it matters.

§9's values are just_sonner's own, settled by feel in the example app. Sonner's equivalents are
worth knowing and are not the answer — do not close a §9 question by copying one.

## Three ways the spec and a reference can differ

- **The spec is silent** — follow the reference, record the divergence.
- **The spec chose differently** — the spec wins. §12 carries the reasoning; it stays settled.
- **The spec drew a wrong conclusion** — it cited the reference correctly and concluded something
  that does not follow from it. Then the spec changes.

The third hides behind the second, because the spec is not silent and so looks decided. A citation
being accurate says nothing about the sentence built on it. When the spec is wrong, change it in the
same session and add a §12 row: what was believed, what was observed, why the new rule follows.
Replace the old wording rather than softening it.
