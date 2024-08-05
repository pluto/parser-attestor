compile:
    circom circuit/extract.circom -o circuit --r1cs --wasm

witness:
    node circuit/extract_js/generate_witness.js circuit/extract_js/extract.wasm circuit/witness.json circuit/witness.wtns

test:
    yarn test 
    rm -rf circuits