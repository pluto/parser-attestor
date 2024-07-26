# SPARK
> Succinct Parser Attestation for Reconciliation of Knowledge 

## Repo Structure
The repository is currently new and being organized as follows:
 - `src/`
    - Example Rust code to test against circom circuits.
    - Used for doing witness generation
 - `circuit/`
    - Has current implementation of circuits
    - TODO
 - `generator/` 
    - Will be where we write code that generates circom from Rust (or other API) frontend

## Instructions

### Installing `circom` and `snarkjs` toolchain
Feel free to follow [these instructions](https://docs.circom.io/getting-started/installation/#installing-dependencies).
Quickly, somewhere on your machine, run the following to get `circom`:
```
git clone https://github.com/iden3/circom.git
cd circom
cargo build --release
cargo install --path circom
```
Then we get `snarkjs` by:
```
npm install -g snarkjs
```