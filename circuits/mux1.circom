// from: https://github.com/iden3/circomlib/blob/master/circuits/mux1.circom

pragma circom 2.1.9;

template MultiMux1(n) {
    signal input c[n][2];  // Constants
    signal input s;   // Selector
    signal output out[n];

    for (var i=0; i<n; i++) {

        out[i] <== (c[i][1] - c[i][0])*s + c[i][0];

    }
}

template Mux1() {
    var i;
    signal input c[2];  // Constants
    signal input s;   // Selector
    signal output out;

    component mux = MultiMux1(1);

    for (i=0; i<2; i++) {
        mux.c[0][i] <== c[i];
    }

    s ==> mux.s;

    mux.out[0] ==> out;
}

template MultiMux2(n) {
    signal input c[n][4];  // Constants
    signal input s[2];   // Selector
    signal output out[n];

    signal a10[n];
    signal a1[n];
    signal a0[n];
    signal a[n];

    signal  s10;
    s10 <== s[1] * s[0];

    for (var i=0; i<n; i++) {

          a10[i] <==  ( c[i][ 3]-c[i][ 2]-c[i][ 1]+c[i][ 0] ) * s10;
           a1[i] <==  ( c[i][ 2]-c[i][ 0] ) * s[1];
           a0[i] <==  ( c[i][ 1]-c[i][ 0] ) * s[0];
            a[i] <==  ( c[i][ 0] );

          out[i] <==  (  a10[i] +  a1[i] +  a0[i] +  a[i] );

    }
}

template Mux2() {
    var i;
    signal input c[4];  // Constants
    signal input s[2];   // Selector
    signal output out;

    component mux = MultiMux2(1);

    for (i=0; i<4; i++) {
        mux.c[0][i] <== c[i];
    }

    for (i=0; i<2; i++) {
      s[i] ==> mux.s[i];
    }

    mux.out[0] ==> out;
}