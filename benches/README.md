# Benchmark

run `cargo run` to run the benchmark natively.

> Note: you might need to download tau file using
> `curl "https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_19.ptau"`

```
Testing circuit with circom:
        23470 constraints
        setup generated in 24482ms
        compiled in 910ms
        execution in 97ms
        prove in 1224ms
Testing noir_string_search with Noir:
        0 constraints (2051 ACIR opcodes)
        setup generated in 0ms
        compiled in 673ms
        execution in 468ms
        prove in 279ms
```
