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

### Running an example
```
circom extractor.circom --r1cs --wasm

# in rust? circom witness rs
node extractor_js/generate_witness.js extractor_js/extractor.wasm input.json witness.wtns

##
# IF YOU NEED A NEW pot (works for all circuits)
snarkjs powersoftau new bn128 14 pot14_0000.ptau -v
snarkjs powersoftau contribute pot14_0000.ptau pot14_0001.ptau --name="First contribution" -v
snarkjs powersoftau prepare phase2 pot14_0001.ptau pot14_final.ptau -v
##

snarkjs groth16 setup extractor.r1cs pot14_final.ptau extractor_0000.zkey

snarkjs zkey contribute extractor_0000.zkey extractor_0001.zkey --name="1st Contributor Name" -v

snarkjs zkey export verificationkey extractor_0001.zkey verification_key.json

# in rust
snarkjs groth16 prove extractor_0001.zkey witness.wtns proof.json public.json

# in rust
snarkjs groth16 verify verification_key.json public.json proof.json
```

## Circomkit
You will need `yarn` on your system (brew, or apt-get or something). 
Then run: `npm install` to get everything else.

### Commands
To see what you can do, I suggest running:
```
npx circomkit help
```

#### Compiling and Witnessgen
For example, to compile the extractor, you can:
```
npx circomkit compile extract
```
Then you can do 
```
npx circomkit witness witness
```

## Notes
Circomkit can probably be used pretty nicely here if we want to. It could replace the Justfile in many ways or at least make that even easier. Food for thought.