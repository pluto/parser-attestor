pragma circom 2.0.0;

template Extractor(MAX_NUM_KEYS, MAX_NUM_KEY_BITS, MAX_NUM_DATA_BITS) {
    signal input num_keys;
    signal input key_sizes[MAX_NUM_KEYS];
    signal input keys[MAX_NUM_KEYS][MAX_NUM_KEY_BITS];
    signal input num_data_bits;
    signal input data[MAX_NUM_DATA_BITS];
    
    // Needed in order to not have a bug when verifying
    signal output out;
    out <== 1;
 

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
    //--------------------------------------------------------------------------------------------//
    // Constrain the data comes in all as bits
    component dataBitConstraint = BitConstraint(MAX_NUM_DATA_BITS);
    dataBitConstraint.bits <== data;

    // Constrain that the keys come in all as bits
    component keyBitConstraints[MAX_NUM_KEYS];
    for(var key_idx = 0; key_idx < MAX_NUM_KEYS; key_idx++) {
        keyBitConstraints[key_idx] = BitConstraint(MAX_NUM_KEY_BITS);
        keyBitConstraints[key_idx].bits <== keys[key_idx];
    }
    //--------------------------------------------------------------------------------------------//


    //--------------------------------------------------------------------------------------------//
    //-SUBSTRING_MATCH----------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    // Used to track the state of the reader
    var pointer = 0;
    var depth = 0;

    // Instructions to match against
    var increase_depth = 0;
    var decrease_depth = 1;
    var end_of_file = 2;

    while(depth < num_keys) {
        var instruction_value = get_instruction();
        
        if(instruction_value == 0) {

        } 

        if(instruction_value == 1) {

        }

        if(instruction_value == 2) {

        }
    }


    //--------------------------------------------------------------------------------------------//
 }

 template BitConstraint(n) {
    signal input bits[n];

    for (var i = 0; i<n; i++) {
        bits[i] * (bits[i] - 1) === 0;
    }
 }

 function get_instruction() {
    return 0;
 }
    // let key_length = key.len();

    // // dbg!(String::from_utf8_lossy(key));

    // 'outer: for i in 0..(data_bytes.len() - key_length) {
    //     #[allow(clippy::needless_range_loop)]
    //     for j in 0..key_length {
    //         // dbg!(String::from_utf8_lossy(&[data_bytes[i..i + key_length][j]]));
    //         if data_bytes[i..i + key_length][j] == b"}"[0] {
    //             // Hit an end brace "}" so we need to return the current pointer as an offset and decrease depth
    //             return Instruction::DecreaseDepth(i + j);
    //         }
    //         if key[j] ^ data_bytes[i..i + key_length][j] != 0 {
    //             continue 'outer;
    //         }
    //     }
    //     // If we hit here then we must have fully matched a key so we return the current pointer as an offset
    //     return Instruction::IncreaseDepth(i + key_length);
    // }
    // // If we hit here, we must have hit EOF (which is actually an error?)
    // Instruction::EOF
//  }

    // // Loop over all the data byte by byte
    // for(var data_byte_idx = 0; data_byte_idx < MAX_NUM_DATA_BITS - 8; data_byte_idx = data_byte_idx + 8) {
    //     // Scan each byte bit by bit
        
    //     for(var bit = 0; bit < 8; bit++){
    //         // Constrain that every element of `data` is a bit
    //         data[data_byte_idx + bit] * (data[data_byte_idx + bit] - 1) === 0;
    //     }
    // }


// TODO: change max here as needed
// The numbers used here come from the `example.json` witnessgen
component main = Extractor(3, 80, 6296);