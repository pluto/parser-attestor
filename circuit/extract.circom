pragma circom 2.1.9;

include "bytes.circom";
include "operators.circom";

template Extract(MAX_NUM_KEYS, MAX_NUM_KEY_BYTES, MAX_NUM_DATA_BYTES) {
    signal input num_keys;
    signal input key_sizes[MAX_NUM_KEYS];
    signal input keys[MAX_NUM_KEYS][MAX_NUM_KEY_BYTES];
    signal input num_data_bytes;
    signal input data[MAX_NUM_DATA_BYTES];

    // TODO: Add assertions on the inputs here!
    // // Make sure there are some keys to use
    // assert(num_keys > 0);

    // // Make sure we specify at least a byte
    // assert(MAX_NUM_KEY_BITS > 8);

    // // Make sure we specify byte-aligned for the maximum number possible of bits in each key
    // assert(MAX_NUM_KEY_BITS % 8 == 0);

    // // Make sure the number of bits of data comes in byte aligned
    // assert(num_data_bits % 8 == 0);

    // // Make sure that the amount of bits of data is less than the maximum allowed
    // assert(num_data_bits <= MAX_NUM_DATA_BITS);


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

    // // DEBUG
    // signal first_key[MAX_NUM_KEY_BYTES];
    // first_key <== keyASCII[0].out;
    // for(var i = 0; i < MAX_NUM_KEY_BYTES; i++) {
    //     log("first_key[", i, "] = ", first_key[i]);
    // }

    // // DEBUG
    // for(var i = 0; i < MAX_NUM_DATA_BYTES; i++) {
    //     log("data[", i, "]", dataASCII.out[i]);
    // }
    //--------------------------------------------------------------------------------------------//

    component Matches[MAX_NUM_DATA_BYTES][MAX_NUM_KEY_BYTES];
    for(var pointer = 0; pointer < MAX_NUM_DATA_BYTES; pointer++) {
        for(var key_byte_index = 0; key_byte_index < 1; key_byte_index++) {
            Matches[pointer][key_byte_index] = IsEqual();
            Matches[pointer][key_byte_index].in[0] <== keys[0][key_byte_index];
            Matches[pointer][key_byte_index].in[1] <== data[key_byte_index];
            log("Matches[", pointer, "]", "[", key_byte_index, "]", Matches[pointer][key_byte_index].out);
        }

    }


}

component main = Extract(3, 10, 787);