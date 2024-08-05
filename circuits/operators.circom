pragma circom 2.1.9;

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
    signal input in[n][2];
    signal output out;

    var accum = 0;
    component equalComponent[n];

    for(var i = 0; i < n; i++) {
        equalComponent[i] = IsEqual();
        equalComponent[i].in[0] <== in[i][0];
        equalComponent[i].in[1] <== in[i][1];
    }

    for(var i = 0; i < n; i++) {
        accum += equalComponent[i].out;
    }

    component totalEqual = IsEqual();
    totalEqual.in[0] <== n;
    totalEqual.in[1] <== accum;
    out <== totalEqual.out;
}