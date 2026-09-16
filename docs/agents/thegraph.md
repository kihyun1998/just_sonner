# thegraph build

## What this project is

A Flutter stacking-toast package. `docs/spec.md` is the contract; where a reference disagrees with
it, the spec wins. **Matching sonner is not a goal**: sonner is read because it answers "what
happens when…" cheaply, and it does not set this package's values.

## References

| Source | Informs | Reached by | Binding |
|---|---|---|---|
| emilkowalski/sonner | how it works | `research/sonner-values.md` on the `research/sonner-values` branch first. It is **summarized** but line-linked, so settle a question by following the link. Otherwise the source tree, raw. Say which one you used | example: where the spec is silent, follow sonner and record the divergence |
| flash (`FlashBar`, `FlashController`) | how it works | its source tree, raw | binding for the §1 adapter only |
| Flutter SDK (Overlay, animation) | how it works | local SDK source, raw | binding |
| The example app (`example/`) | how it looks and moves | running it, as `example/README.md` says | binding for §9 and any "does this read right" question. Sonner's equivalent never closes one |

## When the spec and a reference differ

- **The spec is silent**: follow the reference and record the divergence.
- **The spec chose differently**: the spec wins, and §12 keeps it settled.
- **The spec drew a wrong conclusion** from an accurate citation: the spec changes in the same
  session, with a §12 row saying what was believed, what was observed and why the new rule follows.
  This case hides behind the one above, because the spec is not silent and so looks decided.
