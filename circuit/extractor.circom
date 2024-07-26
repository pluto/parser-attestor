pragma circom 2.0.0;

template Extractor() {
    signal input keys[1];
    signal input random;
    signal output out;
    var x = keys[0] ^ random;
 }

 component main = Extractor();