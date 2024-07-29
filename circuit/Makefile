# Variables
CIRCOM_FILE = extractor.circom
R1CS_FILE = extractor.r1cs
WASM_FILE = extractor_js/extractor.wasm
INPUT_FILE = input.json
WITNESS_FILE = witness.wtns
ZKEY_FILE = extractor_0000.zkey
CONTRIBUTED_ZKEY_FILE = extractor_0001.zkey
FINAL_ZKEY_FILE = extractor.zkey
PUBLIC_FILE = public.json
PROOF_FILE = proof.json
VERIFIER_FILE = verifier.sol
POT_FILE = pot14_0001.ptau
FINAL_POT_FILE = pot14_final.ptau
VERIFICATION_KEY_FILE = verification_key.json

# Commands
CIRCOM = circom
SNARKJS = snarkjs

.PHONY: all clean

all: verify

# Compile Circom file
$(R1CS_FILE) $(WASM_FILE): $(CIRCOM_FILE)
	@echo "Compiling Circom file: $(CIRCOM_FILE)"
	$(CIRCOM) $< --r1cs --wasm

# Generate witness
$(WITNESS_FILE): $(WASM_FILE) $(INPUT_FILE)
	@echo "Generating witness using $(WASM_FILE) and $(INPUT_FILE)"
	node extractor_js/generate_witness.js $^ $@

# Prepare phase 2
$(FINAL_POT_FILE): $(POT_FILE)
	@echo "Preparing phase 2 with $(POT_FILE)"
	$(SNARKJS) powersoftau prepare phase2 $< $@ -v

# Setup phase
$(ZKEY_FILE): $(R1CS_FILE) $(FINAL_POT_FILE)
	@echo "Setting up zkey with $(R1CS_FILE) and $(FINAL_POT_FILE)"
	$(SNARKJS) groth16 setup $(R1CS_FILE) $(FINAL_POT_FILE) $@

# Contribute to phase 2
$(CONTRIBUTED_ZKEY_FILE): $(ZKEY_FILE)
	@echo "Contributing to zkey with $(ZKEY_FILE)"
	$(SNARKJS) zkey contribute $< $@ --name="1st Contributor Name" -v

# Export verification key
$(VERIFICATION_KEY_FILE): $(CONTRIBUTED_ZKEY_FILE)
	@echo "Exporting verification key from $(CONTRIBUTED_ZKEY_FILE)"
	$(SNARKJS) zkey export verificationkey $< $@

# Generate proof
$(PROOF_FILE) $(PUBLIC_FILE): $(WITNESS_FILE) $(CONTRIBUTED_ZKEY_FILE)
	@echo "Generating proof using $(WITNESS_FILE) and $(CONTRIBUTED_ZKEY_FILE)"
	$(SNARKJS) groth16 prove $(WITNESS_FILE) $(CONTRIBUTED_ZKEY_FILE) $(PROOF_FILE) $(PUBLIC_FILE)

# Verify proof
verify: $(PROOF_FILE) $(PUBLIC_FILE) $(VERIFICATION_KEY_FILE)
	@echo "Verifying proof with $(VERIFICATION_KEY_FILE), $(PUBLIC_FILE), and $(PROOF_FILE)"
	$(SNARKJS) groth16 verify $(VERIFICATION_KEY_FILE) $(PUBLIC_FILE) $(PROOF_FILE)

clean:
	@echo "Cleaning up generated files"
	rm -f $(R1CS_FILE) $(WITNESS_FILE) $(ZKEY_FILE) $(CONTRIBUTED_ZKEY_FILE) $(FINAL_ZKEY_FILE) $(PROOF_FILE) $(PUBLIC_FILE) $(VERIFIER_FILE) $(FINAL_POT_FILE) $(VERIFICATION_KEY_FILE)
	rm -rf extractor_js

.PHONY: all clean verify
