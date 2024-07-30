pragma circom 2.0.0;

template Extractor(MAX_NUM_KEYS, MAX_NUM_KEY_BITS, MAX_NUM_DATA_BITS) {
    signal input num_keys;
    signal input num_data_bits;
    // signal input keys[MAX_NUM_KEYS][MAX_NUM_KEY_BITS];
    signal input data[MAX_NUM_DATA_BITS];
    var pointer = 0;
    var depth = 0;
    signal output out;

    // Make sure there are some keys to use
    assert(num_keys > 0);

    // Make sure we specify at least a byte
    assert(MAX_NUM_KEY_BITS > 8);

    // Make sure we specify byte-aligned for the maximum number possible of bits in each key
    assert(MAX_NUM_KEY_BITS % 8 == 0);

    // Make sure the number of bits of data comes in byte aligned
    assert(num_data_bits % 8 == 0);

    // // Make sure there is more data than each key (NOT IN USE)
    // assert(num_key_bits < num_data_bits);

    // // Make sure the number of bits of any given key is less than the max (NOT IN USE)
    // assert(num_key_bits < MAX_NUM_KEY_BITS);

    // Make sure that the amount of bits of data is less than the maximum allowed
    assert(num_data_bits <= MAX_NUM_DATA_BITS);
    
    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//

    // TODO: don't use some MAX if possible, and base this off the real length of the key/data
    // Constrain that every `key` inside of `keys` is an array of bits
    // for(var key_idx = 0; key_idx < MAX_NUM_KEYS; key_idx++) {
    //     for(var key_bit_idx = 0; key_bit_idx < MAX_NUM_KEY_BITS; key_bit_idx++) {
    //         keys[key_idx][key_bit_idx] * (keys[key_idx][key_bit_idx] - 1) === 0;
    //     }
    // }

    // // Loop over all the data byte by byte
    for(var data_byte_idx = 0; data_byte_idx < MAX_NUM_DATA_BITS - 8; data_byte_idx = data_byte_idx + 8) {
        // Scan each byte bit by bit
        for(var bit = 0; bit < 8; bit++){
            // Constrain that every element of `data` is a bit
            data[data_byte_idx + bit] * (data[data_byte_idx + bit] - 1) === 0;
        }
    }
    //--------------------------------------------------------------------------------------------//


    //--------------------------------------------------------------------------------------------//
    //-SUBSTRING_MATCH----------------------------------------------------------------------------//
    // TODO

    out <== 1;
 }




// TODO: change max here as needed
// The numbers used here come from the `example.json` witnessgen
component main = Extractor(3, 80, 6296);