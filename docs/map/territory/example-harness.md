# Example harness

## What it is
The desktop app under `example/`: a showcase with every option on one page, the harness
that makes every behaviour pressable behind it, and their own small test suite. It is where values the spec left provisional are settled by feel, and where
a change is verified by a person rather than by an assertion.

## Governing decisions
- [spec §10](../../spec.md#10-proof) — the example app's place in the proof.
- Its running order and its definition of done live in the tracker, not in a §12 row.

## Design model
The package is built one issue at a time and **each one is verified here before the next
starts**. Every section of the panel names the issue it came from; a change to a
behaviour changes its section in the same change. The panel is laid out in **teaching**
order, not issue order, because features were built in dependency order — the cap came
before the clear-all control, since the control had no far end to sit against until the
cap gave it one.

The showcase is the other half: **every option on one page**, so a new `show` argument or
config field gets a control on its left side in the same change that adds it, and a
situation worth watching whatever the options are goes under its Scenarios.

`example/` is a separate package with its own manifest, so it resolves separately from
the package it demonstrates and can be broken without any gate here noticing.

## Code

**None.** The app is `example/lib/`: `showcase.dart` the page it opens on, `harness.dart`
and its `playground.dart` part behind it, and the looks, settings and flash adapter both
share. Nothing under `lib/` belongs to this territory, and the symbol check stands down.

## Reference behaviour

**None.** sonner's own example never closes the "does this read right" question — it is
a website, and the values it shows were not chosen for this package.

## Cross-cutting invariants

**None.** The harness reads every other territory and shares an assumption with none.

## Blast radius
- [Publishing](publishing.md) — `example/` is part of the archive.
- Every territory — a behaviour change is expected to change the section that presses it.

## Known holes / open
- **A widget is not a value to compare.** A control that offers widgets, such as the
  `loadingIndicator` one, cannot find the config's default by writing the same `const`
  constructor again: debug builds track where each widget was created, so the two are
  different objects and a dropdown asserts that none of its items match. It reads the
  default off `const SonnerConfig()` instead.
- The harness's own suite is **not run by the repository's `flutter test`**: it is a
  separate package, so a change that breaks it is invisible to the root gate.
- **#29 is open** and stays open until the last section lands and §9 is settled. Its
  definition of done for a feature — add the section, then run it and report — is the
  binding check that no assertion replaces.
