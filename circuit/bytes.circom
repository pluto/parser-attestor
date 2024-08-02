pragma circom 2.1.9;

// Converts a u8 number into a byte, 
// verifying that this number does indeed fit into u8 (i.e., will fail if >256 is input)
// See: https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/bitify.circom
template U8ToBits() {
    signal input in;
    signal output out[8];
    var lc1 = 0;

    // log("input to u8ToByte: ", in);

    var e2 = 1;
    for (var i = 0; i < 8; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] - 1) === 0;
        lc1 += out[i] * e2;
        e2 = e2 + e2;
    }
    lc1 === in;
}

// See: https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/bitify.circom
template BitsToU8() {
    signal input in[8];
    signal output out;
    var lc1=0;

    var e2 = 1;
    for (var i = 0; i < 8; i++) {
        lc1 += in[i] * e2;
        e2 = e2 + e2;
    }

    lc1 ==> out;
}

template ASCII(n) {
    signal input in[n];
    signal output out[n];

    component Byte[n];
    component ValidU8[n];
    for(var i = 0; i < n; i++) {
        Byte[i] = U8ToBits();
        Byte[i].in <== in[i];
        // // Debug
        // for(var j = 1; j < 8; j++) {
        //     log("Byte[i].out: ", Byte[i].out[j]);
        // }
        ValidU8[i] = BitsToU8();
        ValidU8[i].in <== Byte[i].out;
        out[i] <== ValidU8[i].out;
    }
}