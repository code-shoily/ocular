# Optic Laws

This document describes the mathematical laws that optics must satisfy and how they are tested in the Ocular library.

## Overview

Optics in functional programming must satisfy certain algebraic laws to ensure they behave correctly and compose predictably. The Ocular library includes comprehensive property-based tests to verify these laws hold for all optic implementations.

## Test File

See `test/ocular_laws_test.gleam` for the full test suite. This file includes:
- **Property-based tests** using `qcheck` to test laws across randomly generated inputs
- **Example-based tests** for specific edge cases
- Tests for all optic types (Lens, Prism, Iso, Optional, Epimorphism, Traversal)

## Lens Laws

Lenses must satisfy three fundamental laws:

### 1. GetPut Law (You get what you set)
```gleam
set(s, l, get(s, l)) == s
```
If you set a value to what it already is, nothing changes.

### 2. PutGet Law (You get what you just put)
```gleam
get(set(s, l, v), l) == v
```
If you set a value and then get it, you get back what you set.

### 3. PutPut Law (Setting twice is setting once)
```gleam
set(set(s, l, v1), l, v2) == set(s, l, v2)
```
The second set wins; the first is irrelevant.

**Property Tests:**
- `lens_law_get_put_property_test()`
- `lens_law_put_get_property_test()`
- `lens_law_put_put_property_test()`

## Prism Laws

Prisms must satisfy laws related to their bidirectional nature:

### 1. ReviewPreview Law
```gleam
preview(review(p, v)) == Ok(v)
```
If you review (construct) a value and then preview it, you get back what you constructed.

### 2. PreviewReview Law (when preview succeeds)
If preview succeeds on a value, then modifying through the prism preserves the variant structure.

**Property Tests:**
- `prism_law_review_preview_some_test()`
- `prism_law_review_preview_ok_test()`
- `prism_law_review_preview_error_test()`

## Iso Laws

Isomorphisms must be truly reversible:

### 1. GetReverse Law
```gleam
reverse(iso, get(iso, s)) == s
```
Going forward then backward gets you back to where you started.

### 2. ReverseGet Law
```gleam
get(iso, reverse(iso, a)) == a
```
Going backward then forward gets you back to where you started.

**Property Tests:**
- `iso_law_get_reverse_test()`
- `iso_law_reverse_get_test()`

## Optional Laws

Optionals satisfy lens-like laws when the path exists:

### 1. GetSetOpt Law (when get succeeds)
If `get_opt` succeeds, setting to that value should preserve the structure.

### 2. PutGetOpt Law
```gleam
get_opt(set_opt(s, opt, v), opt) == Ok(v)
```
If you set a value, getting it should return that value.

**Property Tests:**
- `optional_law_get_set_dict_test()`
- `optional_law_put_get_dict_test()`

## Epimorphism Laws

Epimorphisms must satisfy partial isomorphism laws:

### 1. GetReverse Law (when get succeeds)
When the forward direction succeeds, reversing should get you back.

### 2. ReverseGet Law
```gleam
get_epi(reverse_epi(epi, a), epi) == Ok(a)
```
The reverse direction is always defined, so reversing then getting should work.

**Property Tests:**
- `epimorphism_law_get_reverse_test()`
- `epimorphism_law_reverse_get_test()`

## Traversal Laws

Traversals must satisfy laws about multi-focus operations:

### 1. SetAllGetAll Law
```gleam
get_all(set_all(s, trav, v), trav) == list of v's with same length
```
Setting all to a constant then getting all should return that constant for each element.

### 2. ModifyAll Equivalence
```gleam
modify_all(xs, list_traversal(), f) == list.map(xs, f)
```
For list traversals, modifying all should be equivalent to mapping.

**Property Tests:**
- `traversal_law_set_all_get_all_test()`
- `traversal_law_modify_all_equivalence_test()`

## Additional Laws Tested

### Identity Lens Laws
The identity lens `ocular.id()` must satisfy all lens laws:
- `identity_lens_law_get_put_test()`
- `identity_lens_law_put_get_test()`

### Composed Lenses
Composition must preserve lens laws:
- `composed_lens_law_get_put_test()`

### Modify Equivalence
```gleam
modify(s, l, f) == set(s, l, f(get(s, l)))
```
Modify should be equivalent to get-then-set:
- `lens_modify_equivalence_test()`

### Tuple Lenses
Built-in tuple lenses must satisfy lens laws:
- `tuple_first_lens_law_get_put_test()`
- `tuple_second_lens_law_put_get_test()`

## Edge Cases

The test suite also includes example-based tests for edge cases:
- Empty strings
- Missing dictionary keys
- None values in prisms
- Negative list indices

## Running the Tests

```sh
gleam test
```

All law tests use property-based testing to verify laws across hundreds of randomly generated test cases, ensuring the laws hold universally rather than just for hand-picked examples.

## Why These Laws Matter

These laws ensure:
1. **Predictability**: Optics behave consistently
2. **Composability**: Complex optics built from simpler ones work correctly
3. **Refactoring Safety**: Code using optics can be refactored without changing behavior
4. **Mathematical Soundness**: The library correctly implements category-theoretic concepts

## References

- [Monocle Optics Guide](https://www.optics.dev/Monocle/docs/optics)
- [Haskell Lens Package Laws](https://hackage.haskell.org/package/lens)
- [nLab - Lens in Computer Science](https://ncatlab.org/nlab/show/lens+(in+computer+science))
