# `pabuild` CLI Tool
This repository contains a small Rust CLI tool called `pabuild`.

## Install `pabuild`
From the root of this repository, run:
```sh
cargo install --path .
```
to install the `pabuild` binary.
You can see a help menu with the subcommands by:
```sh
pabuild --help
```

## Witnessgen
To get the basic idea, run
```sh
pabuild witness --help
```
It can process and generate JSON files to be used for these circuits.

### Examples
**JSON Parsing:**
If we have a given JSON file we want to parse such as [`examples/json/test/example.json`](../examples/json/test/example.json) for the `json-parser` circuit (see [`circuits.json`](../circuits.json)), then we can:

```sh
pabuild witness json --input-file examples/json/test/example.json --output-dir inputs/json-parser --output-filename input.json json
```

Afterwards, you can run `npx circomkit compile json-parser` then `circomkit witness json-parser input`.

**HTTP Parsing:**
If we have a given HTTP request/response (as a file) we want to parse such as [`examples/http/get_request.http`](../examples/http/get_request.http) for the `http-parser` circuit (see `circuits.json`), then we can:

```sh
pabuild witness http --input-file examples/json/get_request.http --output-dir inputs/http-parser --output-filename input.json http
```

Afterwards, you can run `npx circomkit compile http-parser` then `circomkit witness http-parser input`.

## Codegen

### JSON Extraction
JSON extractor circuit is generated using rust to handle arbitrary keys and array indices.

Run:
```sh
pabuild json --help
```
to get options:
```
Usage: pabuild json [OPTIONS] --template <TEMPLATE>

Options:
  -t, --template <TEMPLATE>                Path to the JSON file selective-disclosure template
  -o, --output-filename <OUTPUT_FILENAME>  Output circuit file name [default: extractor]
  -d, --debug                              Optional circuit debug logs
  -h, --help                               Print help
```
Takes 3 input arguments:
- `template`: input json file. Examples are located in [extractor](../examples/extractor/).
  - Should contain only two keys:
    - `keys`: list of all the keys in the input json
    - `value_type`: Currently only two value types are supported: `String`,`Number`.
- `output-filename`: circuit filename to save. Located in [circuits/main](../circuits/main/). If not given, defaults to `extractor.circom`.
- `debug`: Optional debug logs for parser and extractor output.

To test an end-to-end JSON extraction proof:
- Run codegen to generate circuits. Replace `value_string` with input filename.
   ```sh
   pabuild json --template examples/json/extractor/value_string.json --output-filename value_string
   ```

- Compile circom circuit using
   ```
   circom ./circuits/main/value_string.circom --r1cs --wasm
   ```

- To use circomkit: add circuit config to [circuits.json](../circuits.json). and input file to [inputs](../inputs/)

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

### HTTP Locking and Extraction

TODO