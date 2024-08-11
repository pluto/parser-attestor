pragma circom 2.1.9;

include "bytes.circom";

// For both see: https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/comparators.circom

template IsZero() {
    signal input in;
    signal output out;

    signal inv;

    inv <-- in!=0 ? 1/in : 0;

    out <== -in * inv + 1;
    in * out === 0;
}


template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();

    in[1] - in[0] ==> isz.in;

    isz.out ==> out;
}

template IsEqualArray(n) {
    signal input in[2][n];
    signal output out;

    var accum = 0;
    component equalComponent[n];

    for(var i = 0; i < n; i++) {
        equalComponent[i] = IsEqual();
        equalComponent[i].in[0] <== in[0][i];
        equalComponent[i].in[1] <== in[1][i];
        accum += equalComponent[i].out;
    }

    component totalEqual = IsEqual();
    totalEqual.in[0] <== n;
    totalEqual.in[1] <== accum;
    out <== totalEqual.out;
}

template LessThan(n) {
    assert(n <= 252);
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n+1);

    n2b.in <== in[0]+ (1<<n) - in[1];

    out <== 1-n2b.out[n];
}

// N is the number of bits the input  have.
// The MSF is the sign bit.
template LessEqThan(n) {
    signal input in[2];
    signal output out;

    component lt = LessThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1]+1;
    lt.out ==> out;
}

// N is the number of bits the input  have.
// The MSF is the sign bit.
template GreaterThan(n) {
    signal input in[2];
    signal output out;

    component lt = LessThan(n);

    lt.in[0] <== in[1];
    lt.in[1] <== in[0];
    lt.out ==> out;
}

// N is the number of bits the input  have.
// The MSF is the sign bit.
template GreaterEqThan(n) {
    signal input in[2];
    signal output out;

    component lt = LessThan(n);

    lt.in[0] <== in[1];
    lt.in[1] <== in[0]+1;
    lt.out ==> out;
}

template InRange(n) {
    signal input in;
    signal input range[2];
    signal output out;

    component gte = GreaterEqThan(n);
    gte.in <== [in, range[0]];
    log("gte.out: ", gte.out);

    component lte = LessEqThan(n);
    lte.in <== [in, range[1]];
    log("lte.out: ", lte.out);

    out <== gte.out * lte.out;
}