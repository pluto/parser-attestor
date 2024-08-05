pragma circom 2.1.9;

include "bytes.circom";
include "operators.circom";

template Extract(KEY_BYTES, DATA_BYTES) {
    signal input key[KEY_BYTES];
    signal input data[DATA_BYTES];
    signal output KeyMatches[DATA_BYTES - KEY_BYTES];

    // TODO: Add assertions on the inputs here!

    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    // Working with a single key for now to do substring matching
    component keyASCII = ASCII(KEY_BYTES);
    keyASCII.in <== key;
    
    component dataASCII = ASCII(DATA_BYTES);
    dataASCII.in <== data;
    //--------------------------------------------------------------------------------------------//
    component Matches[DATA_BYTES];
    for(var data_pointer = 0; data_pointer < DATA_BYTES - KEY_BYTES; data_pointer++) {
        Matches[data_pointer] = IsEqualArray(KEY_BYTES);
        for(var key_pointer_offset = 0; key_pointer_offset < KEY_BYTES; key_pointer_offset++) {
            Matches[data_pointer].in[0][key_pointer_offset] <== key[key_pointer_offset];
            Matches[data_pointer].in[1][key_pointer_offset] <== data[data_pointer + key_pointer_offset];
        }
        log("Matches[", data_pointer, "] = ", Matches[data_pointer].out);
        KeyMatches[data_pointer] <== Matches[data_pointer].out;
    }
}