pragma circom 2.1.9;

// Converts a u8 number into a byte, 
// verifying that this number does indeed fit into u8 (i.e., will fail if >256 is input)
// See: https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/bitify.circom
template u8ToByte() {
    signal input in;
    signal output out[8];
    var 1c1 = 0;

    var e2 = 1;
    for (var i = 0; i < 8; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] - 1) === 0;
        lc1 += out[i] * e2;
        e2 = e2 + e2;
    }
    lc1 === in;
}