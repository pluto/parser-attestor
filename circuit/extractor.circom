pragma circom 2.0.0;

template Extractor(MAX_NUM_KEY_BITS, MAX_NUM_DATA_BITS) {
    signal input num_key_bits;
    signal input num_data_bits;
    signal input key[MAX_NUM_KEY_BITS];
    signal input data[MAX_NUM_DATA_BITS];

    assert(num_key_bits > 8);
    assert(num_key_bits % 8 == 0);
    assert(num_data_bits % 8 == 0);
    assert(num_key_bits < num_data_bits);
    assert(num_key_bits < MAX_NUM_KEY_BITS);
    assert(num_data_bits < MAX_NUM_DATA_BITS);
    
    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//

    // TODO: don't use some MAX if possible, and base this off the real length of the key/data
    // Constrain that every element of `key` is a bit
    for(var key_idx = 0; key_idx < MAX_NUM_KEY_BITS; key_idx++) {
        key[key_idx] * (key[key_idx] - 1) === 0;
    }

    // Loop over all the data byte by byte
    for(var data_idx = 0; data_idx < MAX_NUM_DATA_BITS - 8; data_idx = data_idx + 8) {

        // Scan each byte bit by bit
        for(var bit = 0; bit < 8; bit++){
            // Constrain that every element of `data` is a bit
            data[data_idx + bit] * (data[data_idx + bit] - 1) === 0;
        }

    }
    //--------------------------------------------------------------------------------------------//


    //--------------------------------------------------------------------------------------------//
    //-SUBSTRING_MATCH----------------------------------------------------------------------------//
    // TODO
 }


// TODO: change max here as needed
component main = Extractor(100,100);