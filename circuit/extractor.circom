pragma circom 2.1.9;

// TODO: Mar

template Extractor(MAX_NUM_KEYS, MAX_NUM_KEY_BITS, MAX_NUM_DATA_BITS, MAX_NUM_INSTRUCTIONS) {
    signal input num_keys;
    signal input key_sizes[MAX_NUM_KEYS];
    signal input keys[MAX_NUM_KEYS][MAX_NUM_KEY_BITS];
    signal input num_data_bits;
    signal input data[MAX_NUM_DATA_BITS];
    
    // Needed in order to not have a bug when verifying
    signal output out;
    out <== 1;


    
    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    // Constrain the data comes in all as bits
    component dataBit = Bit(MAX_NUM_DATA_BITS);
    dataBit.bits <== data;

    // Constrain that the keys come in all as bits
    component keyBits[MAX_NUM_KEYS];
    for(var key_idx = 0; key_idx < MAX_NUM_KEYS; key_idx++) {
        keyBits[key_idx] = Bit(MAX_NUM_KEY_BITS);
        keyBits[key_idx].bits <== keys[key_idx];
    }
    //--------------------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------------------//
    //-SUBSTRING_MATCH----------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//
    // Used to track the state of the reader
    var pointer = 0;
    // signal pointer[MAX_NUM_INSTRUCTIONS];
    var depth = 0;

    var INCREASE_DEPTH = 0;    
    var DECREASE_DEPTH = 1;
    var EOF = 2;

    var eof_hit = 0;

    for(var instruction_counter = 0; instruction_counter < MAX_NUM_INSTRUCTIONS; instruction_counter++) {
        var next_instruction[2] = getNextInstruction(data, pointer, keys[depth], key_sizes[depth], MAX_NUM_DATA_BITS);

        if(next_instruction[0] == INCREASE_DEPTH) {
            depth += 1;
            pointer += next_instruction[1];
        } 

        if(next_instruction[0] == DECREASE_DEPTH) {
            depth -= 1;
            pointer += next_instruction[1];
        }

        if(next_instruction[0] == EOF) {
            eof_hit = 1;
        }   

        log("value of instruction_counter is", instruction_counter);
        if(depth == num_keys) {
            debug_pointer[instruction_counter] <== pointer;
        }
    }

    if(eof_hit == 1) {
        // TODO: But we should fail?
    }

    // signal s_0 <== num_keys;
    var test = 5;
    signal s_0 <== test - num_keys; // pointer and depth are NOT quadratic
    signal output name <== (s_0 - 1) * data[2];
    if(depth == num_keys) {
        // TODO: Retrieve the value at the given key
        // out <== data[pointer];
    }
    //--------------------------------------------------------------------------------------------//
}

template Bit(n) {
    signal input bits[n];

    for (var i = 0; i<n; i++) {
        bits[i] * (bits[i] - 1) === 0;
    }
}

template Byte() {
    signal input num;
    signal output bits[8];

}
 
function getNextInstruction(data, start_pointer, key, key_length, MAX_NUM_DATA_BITS) {
    var INCREASE_DEPTH = 0;    
    var DECREASE_DEPTH = 1;
    var EOF = 2;
    var jump_offset = 0;

    var END_BRACE_BITS[8] = [0, 1, 1, 1, 1, 1, 0, 1]; // `}`
    var COMMA_BITS[8] = [0, 0, 1, 0, 1, 1, 0, 0]; // `,`

    // Loop over all the data byte by byte
    for(var pointer = start_pointer; pointer < MAX_NUM_DATA_BITS - 8 - start_pointer; pointer = pointer + 8) {
        //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx//
        // 1. Check to see if we bitmatch an end brace `}`
        var bit_idx = 0;
        var is_end_brace = 0;
        var correct_key_bytes = 0;
        while(bit_idx < 8 && is_end_brace == 0 && correct_key_bytes == key_length / 8){
            // Check here if all bits in this current byte are that of an end brace `}`
            if(data[pointer + bit_idx] != END_BRACE_BITS[bit_idx]) {
                is_end_brace = 1;
            }
            // Check here if all bits in this current byte are that of the current byte of the key (still a bit TODO)
            if(data[pointer + bit_idx] ^ END_BRACE_BITS[bit_idx] != 0) {
                correct_key_bytes++;
            }
            // Did not hit a byte from intended key, so reset
            correct_key_bytes = 0;
        }
        if(is_end_brace == 1) {
            // Hit an end brace "}" so we need to return the current pointer and decrease depth
            return [DECREASE_DEPTH, pointer + 8];
        }
        if(correct_key_bytes == key_length) {
            // Hit a the correct key so we need to return the current pointer and increase depth
            return [INCREASE_DEPTH, pointer + 8];
        }
        //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx//
    }
    return [EOF, jump_offset];
}

// TODO: change max here as needed
// The numbers used here come from the `example.json` witnessgen
component main = Extractor(3, 80, 6296, 100);
