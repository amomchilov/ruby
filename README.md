# An attempt at optimizing `OpenStruct`'s storage

This branch explores any performance improvements that could be gained from optimizing the storage of `OpenStruct`.

Today, the class is just a wrapper around a `Hash` stored in its `@table` property, with some meta-programming to define
methods to give dot access, respond to `#method_missing` to create new fields on the fly, etc.

This pattern incurs a double indirection. Each lookup will first need to follow a pointer to the `OpenStruct` instance,
then another pointer to its `Hash`. This branch explored what might happened if the fields are stored directly as
instance variables on the `OpenStruct` instance itself. It seemed like this could have several benefits:

## (Theoretical) Upside

1. Each `OpenStruct` would only need two allocations (the instance itself, and its singleton class) instead of 3
   (the other two, plus the `Hash` instance).
2. `OpenStruct` instances could have their storage be optimized with the new shapes optimization introduced in Ruby 3.2.
3. The getter methods no longer have to be per-field Procs like `{ @table[key] }`. This reduces allocations,
    but is also much faster, since they can just use regular `attr_reader`s, which has an optimized code path in MRI.

## Challenges

1. Ruby has pretty strict rules for what can be used as an instance variable name, even when using APIs like
    `instance_variable_set`, which could theoretically take any free-form string.

    They must start with `@`, contain only `a-z` or underscores. They can't end in question marks or bangs, etc.

    This has several implications:

    1. Every lookup for a key `:foo` or `"foo"` requires some string processing (and allocation) to derive a `:@foo`.
    2. `OpenStruct` lets you use any arbitrary strings or symbols as field names. Support that would be tricky, and
        would require either encoding all field names to be safe valid names (which kills any performance benefits
        there might have been), or applying some kind of deoptimization when an invalid field name is set, to fall back
        to the previous Hash-based storage pattern.

2. Implementing `#hash`, `#eql?`, `#==`, etc.

    Implementing these in an efficient way can actually be kind of tricky. The `Hash`-based approach has it easy, it can
    just delegate to `Hash`'s implementations of these methods.

    Two obvious solutions come to mind:

    1. Just do something like `def =(other) = to_h == other.to_h`, but that would introduce a lot of
    allocations, and have poor performance.
    2. Iterate over `instance_variables`. This also allocates an Array.

    To properly implement these methods in a fast, non-allocating way, we'd need to write a C extension that leverages
    `obj_ivar_each` for iterating over all the instance variables, without allocating any arrays/hashes to hold them.

3. We sacrifice performance in `#[]`, which could otherwise just delegate to `@table[key]`, which is crazy fast.

# Preliminary benchmark results

The benchmark is included under `./ostruct_benchmark.rb`

## Baseline: Ruby 3.2.0, ostruct 0.5.5

```
Warming up --------------------------------------
creation,   0 fields   989.064k i/100ms
creation,   1 field     46.014k i/100ms
creation,   2 fields    22.171k i/100ms
creation,   3 fields    16.145k i/100ms
creation, 100 fields   546.000  i/100ms
    attribute access     1.524M i/100ms
key lookup by string     1.159M i/100ms
key lookup by symbol     1.657M i/100ms
Calculating -------------------------------------
creation,   0 fields     10.500M (± 1.0%) i/s -    210.671M in  20.065330s
creation,   1 field     470.727k (± 1.5%) i/s -      9.433M in  20.043601s
creation,   2 fields    221.024k (± 1.7%) i/s -      4.434M in  20.067781s
creation,   3 fields    163.647k (± 1.3%) i/s -      3.277M in  20.030681s
creation, 100 fields      5.720k (± 2.0%) i/s -    114.660k in  20.053509s
    attribute access     15.061M (± 4.4%) i/s -    301.847M in  20.095317s
key lookup by string     11.594M (± 1.7%) i/s -    231.890M in  20.006283s
key lookup by symbol     16.700M (± 2.7%) i/s -    334.787M in  20.066925s
```

## Treatment: Ruby 3.3.0, ostruct 0.5.6, with optimized OpenStruct

This benchmark run has one huge caveat: I completely circumvent the issue of invalid ivar names. I don't spend any
cycles on trying to sanitize/encode field names. I just give already-valid field names, that can be used as ivar names
as soon as you prefix them with a simple `@`.

Findings:

* Allocation is marginally faster.
* Method-based field access (e.g. `foo.bar` instead of `foo[:bar]`) is 2.5x faster
* `#[]` with a symbol is slower by ~40x (!!)
* `#[]` with a symbol is slower by ~54x (!!!)

The gain from the `attr_reader`, shape-optimized field look ups are great, but the hit to `#[]` look up is just
too large to be a worthwhile trade-off.

I'm curious if there are any glaring issues with the implementation of `#[]`. It makes sense that Hash look-ups
very highly optimized, but I didn't expect it to be quite this drastic.

```
Warming up --------------------------------------
creation,   0 fields     1.173M i/100ms
creation,   1 field     57.015k i/100ms
creation,   2 fields    23.998k i/100ms
creation,   3 fields    17.677k i/100ms
creation, 100 fields   699.000  i/100ms
    attribute access     4.087M i/100ms
key lookup by string   277.808k i/100ms
key lookup by symbol   301.263k i/100ms
Calculating -------------------------------------
creation,   0 fields     12.100M (± 1.1%) i/s -    242.762M in  20.065416s
creation,   1 field     560.927k (± 3.7%) i/s -     11.232M in  20.056293s
creation,   2 fields    235.227k (± 3.0%) i/s -      4.704M in  20.015252s
creation,   3 fields    178.483k (± 3.5%) i/s -      3.571M in  20.036568s
creation, 100 fields      6.884k (± 2.3%) i/s -    137.703k in  20.014773s
    attribute access     40.602M (± 1.1%) i/s -    813.228M in  20.031701s
key lookup by string      2.821M (± 1.2%) i/s -     56.673M in  20.093941s
key lookup by symbol      3.006M (± 5.0%) i/s -     59.951M in  20.016046s
```
