<h1 align="center">
  SPARK
</h1>

<div align="center">
  <a href="https://github.com/pluto/extractor/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/pluto/spark?style=flat-square&logo=github&logoColor=8b949e&labelColor=282f3b&color=32c955" alt="Contributors" />
  </a>
  <a href="https://github.com/pluto/extractor/actions/workflows/test.yaml">
    <img src="https://img.shields.io/badge/tests-passing-32c955?style=flat-square&logo=github-actions&logoColor=8b949e&labelColor=282f3b" alt="Tests" />
  </a>
  <a href="https://github.com/pluto/extractor/actions/workflows/lint.yaml">
    <img src="https://img.shields.io/badge/lint-passing-32c955?style=flat-square&logo=github-actions&logoColor=8b949e&labelColor=282f3b" alt="Lint" />
  </a>
</div>

## Overview

SPARK (Succinct Parser Attestation for Reconciliation of Knowledge) is a project focused on implementing parsers and extractors for various data formats using zero-knowledge proofs.

## Repository Structure

- `src/bin`: Binaries
  - `witness`: Used for witness generation
  - `codegen`: Used for generating extractor circuits based on input
- `circuits/`: Current implementation of circuits
  - `http`: HTTP parser and extractor
  - `json`: JSON parser and extractor
  - `utils`: Utility circuits
  - `test`: Circuit tests
- `examples/`: Reference examples for JSON and HTTP parsers

## Getting Started

### Prerequisites

To use this repo, you need to install the following:

1. `circom` and `snarkjs`:
   ```sh
   git clone https://github.com/iden3/circom.git
   cd circom
   cargo build --release
   cargo install --path circom
   npm install -g snarkjs

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

## Binaries

### Rust Example Witness JSON Creation
To generate example input JSON files for the Circom circuits, run:

```bash
cargo install --path .
```

to install the `witness` binary.

To get the basic idea, run `witness --help`. It can process and generate JSON files to be used for the circuits.
For example, if we have a given JSON file we want to parse such as `examples/json/test/example.json` for the `extract` circuit (see `circuits.json`), then we can:

```bash
witness json --input-file examples/json/test/example.json --output-dir inputs/extract --output-filename input.json
```

For an HTTP request/response, you can generate a JSON input via:
```bash
witness http --input-file examples/http/get_request.http --output-dir inputs/get_request --output-filename input.json
```

Afterwards, you can run `circomkit compile get_request` then `circomkit witness get_request input`.

### Codegen

JSON extractor circuit is generated using rust to handle arbitrary keys and array indices.

Run:
```bash
cargo run --bin codegen -- --help
```
to get options:
```
Usage: codegen [OPTIONS] --json-file <JSON_FILE>

Options:
  -j, --json-file <JSON_FILE>              Path to the JSON file
  -o, --output-filename <OUTPUT_FILENAME>  Output circuit file name [default: extractor]
```
Takes input 2 arguments:
- `json-file`: input json file. Examples are located in [codegen](./examples/json/test/codegen/)
- `output-filename`: circuit filename to save. Located in [circuits/main](./circuits/main/). If not given, defaults to `extractor.circom`.

To test an end-to-end JSON extraction proof:
- Run codegen to generate circuits. Replace `value_string` with input filename.
   ```bash
   cargo run --bin codegen -- --json-file ./examples/json/test/codegen/value_string.json --output-filename value_string
   ```

- Compile circom circuit using
   ```
   circom ./circuits/main/value_string.circom --r1cs --wasm
   ```

- To use circomkit: add circuit config to [circuits.json](./circuits.json). and input file to [inputs](./inputs/)

- Generate witness:
   ```bash
   node build/json_extract_value_string/json_extract_value_string_js/generate_witness inputs/json_extract_value_string/value_string.json build/json_extract_value_string/witness/
   ```
   or generate using circomkit:
   ```bash
   npx circomkit witness json_extract_value_string value_string
   ```

- create trusted setup:
   ```bash
   npx circomkit setup json_extract_value_string
   # OR
   snarkjs groth16 setup build/json_extract_value_string/json_extract_value_string.r1cs ptau/powersOfTau28_hez_final_14.ptau build/json_extract_value_string/groth16_pkey.zkey
   ```

- create proof:
   ```bash
   npx circomkit prove json_extract_value_string value_string
   # OR
   snarkjs groth16 prove build/json_extract_value_string/groth16_pkey.zkey build/json_extract_value_string/value_string/witness.wtns build/json_extract_value_string/value_string/groth16_proof.json inputs/json_extract_value_string/value_string.json
   ```

- verify proof:
   ```bash
   npx circomkit verify json_extract_value_string value_string
   # OR
   snarkjs groth16 verify build/json_extract_value_string/groth16_vkey.json inputs/json_extract_value_string/value_string.json build/json_extract_value_string/value_string/groth16_proof.json
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


## Contributing

We welcome contributions to our open-source projects. If you want to contribute or follow along with contributor discussions, join our [main Telegram channel](https://t.me/pluto_xyz/1) to chat about Pluto's development.

Our contributor guidelines can be found in [CONTRIBUTING.md](./CONTRIBUTING.md). A good starting point is issues labelled 'bounty' in our repositories.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.

## License

Licensed under your option of either:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
