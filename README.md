# SPARK
> Succinct Parser Attestation for Reconciliation of Knowledge

## Repo Structure
The repository is currently new and being organized as follows:
 - `src/`
    - Example Rust code to test against circom circuits.
    - Used for doing witness generation
 - `circuits/`
    - Has current implementation of circuits

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

### Circomkit
You will need `yarn` on your system (brew, or apt-get or something).
Then run: `npm install` to get everything else.

#### Commands
To see what you can do, I suggest running:
```
npx circomkit help
```
from the repository root.

#### Compiling and Witnessgen
For example, to compile the extractor, you can:
```
npx circomkit compile extract
```
Then you can do
```
npx circomkit witness extract witness
```
And even:
```
npx circomkit prove extract witness
```

To clean up, just run:
```
npx circomkit clean extract
```

All of the above should be ran from repository root.

## Rust Example Witness JSON Creation
To generate example input JSON files for the Circom circuits, you can 
```
cargo install --path .
```
to install the `witness` binary. 
To get the basic idea, run `witness --help`. 
It can process and generate JSON files to be used for the circuits.
For example, if we have a given JSON file we want to parse such as `examples/json/test/example.json` for the `extract` circuit (see `circuits.json`), then we can:
```
witness json --input-file examples/json/test/example.json --output-dir inputs/extract --output-filename input.json
```

For an HTTP request/response, you can generate a JSON input via:
```
witness http --input-file examples/http/get_request.http --output-dir inputs/get_request --output-filename input.json
```

## Testing
To test, you can just run
```
npx mocha
```
from the repository root.

To run specific tests, use the `-g` flag for `mocha`, e.g., to run any proof described with "State" we can pass:
```
npx mocha -g State
```

> [!NOTE]
> Currently [search](./circuits/search.circom) circuit isn't working with circomkit, so you might have to compile using circom: `circom circuits/main/search.circom --r1cs --wasm -l node_modules/ -o build/search/`

## (MOSTLY DEPRECATED DUE TO CIRCOMKIT) Running an example
```
circom extract.circom --r1cs --wasm

# in rust? circom witness rs
node extract_js/generate_witness.js extract_js/extract.wasm input.json witness.wtns

##
# IF YOU NEED A NEW pot (works for all circuits)
snarkjs powersoftau new bn128 14 pot14_0000.ptau -v
snarkjs powersoftau contribute pot14_0000.ptau pot14_0001.ptau --name="First contribution" -v
snarkjs powersoftau prepare phase2 pot14_0001.ptau pot14_final.ptau -v
##

snarkjs groth16 setup extract.r1cs pot14_final.ptau extract_0000.zkey

snarkjs zkey contribute extract_0000.zkey extract_0001.zkey --name="1st Contributor Name" -v

snarkjs zkey export verificationkey extractor_0001.zkey verification_key.json

# in rust
snarkjs groth16 prove extractor_0001.zkey witness.wtns proof.json public.json

# in rust
snarkjs groth16 verify verification_key.json public.json proof.json
```
