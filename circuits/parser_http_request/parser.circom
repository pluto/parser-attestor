pragma circom 2.1.9;

include "../utils/bytes.circom";
include "machine.circom";


template Parser(DATA_BYTES) {
    signal input data[DATA_BYTES];

    signal output Method;

    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    component dataASCII = ASCII(DATA_BYTES);
    dataASCII.in <== data;
    //--------------------------------------------------------------------------------------------//

    component ParseMethod = ParseMethod();
    for(var byte_idx = 0; byte_idx < 7; byte_idx++) {
        ParseMethod.bytes[byte_idx] <== data[byte_idx];
    }
    log("MethodTag: ", ParseMethod.MethodTag);
}