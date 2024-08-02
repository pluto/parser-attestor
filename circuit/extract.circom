pragma circom 2.1.9;

include "bytes.circom";

template Extract(MAX_NUM_KEYS, MAX_NUM_KEY_BYTES, MAX_NUM_DATA_BYTES) {
    signal input num_keys;
    signal input key_sizes[MAX_NUM_KEYS];
    signal input keys[MAX_NUM_KEYS][MAX_NUM_KEY_BYTES];
    signal input num_data_bytes;
    signal input data[MAX_NUM_DATA_BYTES];

    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    component keyASCII[MAX_NUM_KEYS];
    for(var key_index = 0; key_index < MAX_NUM_KEYS; key_index++) {
        keyASCII[key_index] = ASCII(MAX_NUM_KEY_BYTES);
        keyASCII[key_index].in <== keys[key_index];
    }
    component dataASCII = ASCII(MAX_NUM_DATA_BYTES);
    dataASCII.in <== data;

    // component isByte = u8ToByte();
    // isByte.in <== 10;

    // log("after byte test");
    // component someASCII = ASCIIToBytes(3);
    // // signal ascii[3] <== [100, 200, 300];
    // someASCII.in <== [100, 200, 300];
}

component main = Extract(3, 10, 787);