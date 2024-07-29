# Makefile for Circom project

# Variables
CIRCOM_FILE = extractor.circom
R1CS_FILE = extractor.r1cs
WASM_FILE = extractor_js/extractor.wasm
INPUT_FILE = input.json
WITNESS_FILE = witness.wtns
ZKEY_FILE = extractor.zkey
PUBLIC_FILE = public.json
PROOF_FILE = proof.json
VERIFIER_FILE = verifier.sol

# Commands
CIRCOM = circom
SNARKJS = snarkjs

.PHONY: all clean

all: verify

# Compile Circom file
$(R1CS_FILE) $(WASM_FILE): $(CIRCOM_FILE)
	$(CIRCOM) $< --r1cs --wasm

# Generate witness
$(WITNESS_FILE): $(WASM_FILE) $(INPUT_FILE)
	node extractor_js/generate_witness.js $^ $@

# Setup phase
$(ZKEY_FILE): $(R1CS_FILE)
	$(SNARKJS) plonk setup $< pot16_final.ptau $@

# Generate proof
$(PROOF_FILE) $(PUBLIC_FILE): $(WITNESS_FILE) $(ZKEY_FILE)
	$(SNARKJS) plonk prove $^ $@ $(@D)/public.json

# Verify proof
verify: $(PROOF_FILE) $(PUBLIC_FILE) $(ZKEY_FILE)
	$(SNARKJS) plonk verify $^ 

# Generate Solidity verifier
$(VERIFIER_FILE): $(ZKEY_FILE)
	$(SNARKJS) zkey export solidityverifier $< $@

clean:
	rm -f $(R1CS_FILE) $(WITNESS_FILE) $(ZKEY_FILE) $(PROOF_FILE) $(PUBLIC_FILE) $(VERIFIER_FILE)
	rm -rf extractor_js

.PHONY: all clean verify