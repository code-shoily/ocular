# Optic Composition Reference

This document details all composition functions available in `ocular/compose`.

## The Composition Rule

When composing optics:
- The resulting optic has the capabilities of the **least powerful** optic in the chain.
- For example:
  - `Lens` + `Lens` = `Lens` (both guaranteed)
  - `Lens` + `Optional` = `Optional` (outer is guaranteed, but inner can fail)
  - `Prism` + `Lens` = `Optional` (outer can fail, inner cannot review without a default)
  - `Traversal` + any optic = `Traversal` (multi-focus dominates)

---

## Full Composition Matrix

| Outer Optic | Inner Optic | Resulting Optic | Function | Description |
|:---|:---|:---|:---|:---|
| **Lens** | **Lens** | `Lens` | `c.lens` | Focus deeper into nested records |
| **Lens** | **Optional** | `Optional` | `c.lens_opt` | Guaranteed path leading to optional field |
| **Optional** | **Lens** | `Optional` | `c.opt_lens` | Optional path leading to guaranteed field |
| **Optional** | **Optional** | `Optional` | `c.optional` | Chained fallible paths |
| **Prism** | **Prism** | `Prism` | `c.prism` | Chained variant matching |
| **Prism** | **Lens** | `Optional` | `c.prism_lens` | Match variant then focus on field |
| **Prism** | **Optional** | `Optional` | `c.prism_opt` | Match variant then try optional path |
| **Iso** | **Iso** | `Iso` | `c.iso` | Chained two-way conversions |
| **Iso** | **Lens** | `Lens` | `c.iso_lens` | Convert type then focus on field |
| **Lens** | **Iso** | `Lens` | `c.lens_iso` | Focus on field then convert type |
| **Iso** | **Prism** | `Prism` | `c.iso_prism` | Convert type then match variant |
| **Prism** | **Iso** | `Prism` | `c.prism_iso` | Match variant then convert type |
| **Iso** | **Optional** | `Optional` | `c.iso_opt` | Convert type then try optional path |
| **Optional** | **Prism** | `Optional` | `c.opt_prism` | Try optional path then match variant |
| **Epimorphism** | **Epimorphism**| `Epimorphism` | `c.epi` | Chained partial conversions |
| **Epimorphism** | **Iso** | `Epimorphism` | `c.epi_iso` | Partial conversion then total conversion |
| **Iso** | **Epimorphism** | `Epimorphism` | `c.iso_epi` | Total conversion then partial conversion |
| **Lens** | **Epimorphism** | `Optional` | `c.lens_epi` | Focus on field then parse/convert |
| **Prism** | **Epimorphism** | `Prism` | `c.prism_epi` | Match variant then parse/convert |
| **Traversal** | **Traversal** | `Traversal` | `c.traversal` | Traverse outer list then inner list |
| **Traversal** | **Lens** | `Traversal` | `c.traversal_lens` | Focus on a field across every item |
| **Lens** | **Traversal** | `Traversal` | `c.lens_traversal` | Focus on list field, then traverse items |
| **Traversal** | **Optional** | `Traversal` | `c.traversal_opt` | Traverse items and keep existing values |
| **Optional** | **Traversal** | `Traversal` | `c.opt_traversal` | Try optional path, then traverse items |
| **Traversal** | **Prism** | `Traversal` | `c.traversal_prism`| Filter and match variants across items |
| **Prism** | **Traversal** | `Traversal` | `c.prism_traversal`| Match variant, then traverse items |
| **Traversal** | **Iso** | `Traversal` | `c.traversal_iso` | Convert each item in a traversal |
| **Iso** | **Traversal** | `Traversal` | `c.iso_traversal` | Convert structure, then traverse items |

---

## Notes on Asymmetric Compositions

### Why `prism_lens` produces an `Optional`, not a `Prism`:
A `Prism` requires a `review` function: `fn(focus) -> whole`.
If you compose `Prism(Whole, Variant)` with `Lens(Variant, Field)`:
- You have `Field`.
- You cannot create `Variant` without knowing the default values for all other fields in `Variant`.
- Therefore, `review` cannot be implemented, and the result degrades to an `Optional`.
