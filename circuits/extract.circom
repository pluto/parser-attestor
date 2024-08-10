pragma circom 2.1.9;

include "bytes.circom";
include "operators.circom";
include "parser.circom";

template Extract(DATA_BYTES) {
    signal input data[DATA_BYTES];

    // TODO: Add assertions on the inputs here!

    //--------------------------------------------------------------------------------------------//
    //-CONSTRAINTS--------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------//    
    component dataASCII = ASCII(DATA_BYTES);
    dataASCII.in <== data;
    //--------------------------------------------------------------------------------------------//
    // Initialze the parser
    component State[DATA_BYTES];
    State[0] = StateUpdate();
    State[0].byte           <== data[0];
    State[0].pointer        <== 0;
    State[0].depth          <== [0,0,0,0];
    State[0].parsing_string <== 0;
    State[0].parsing_array  <== 0;
    State[0].parsing_object <== 0;
    State[0].parsing_number <== 0;
    State[0].key_or_value   <== 0;

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx] = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].pointer        <== State[data_idx - 1].pointer;
        State[data_idx].depth          <== State[data_idx - 1].depth;
        State[data_idx].parsing_string <== State[data_idx - 1].parsing_string;
        State[data_idx].parsing_array  <== State[data_idx - 1].parsing_array;
        State[data_idx].parsing_object <== State[data_idx - 1].parsing_object;
        State[data_idx].parsing_number <== State[data_idx - 1].parsing_number;
        State[data_idx].key_or_value   <== State[data_idx - 1].key_or_value;

        // Debugging
        log("State[", data_idx, "].pointer       ", "= ", State[data_idx].pointer);
        for(var i = 0; i<4; i++) {
            log("State[", data_idx, "].depth[", i,"]    ", "= ", State[data_idx].depth[i]);
        }
        log("State[", data_idx, "].parsing_string", "= ", State[data_idx].parsing_string);
        log("State[", data_idx, "].parsing_array ", "= ", State[data_idx].parsing_array );
        log("State[", data_idx, "].parsing_object", "= ", State[data_idx].parsing_object);
        log("State[", data_idx, "].parsing_number", "= ", State[data_idx].parsing_number);
        log("State[", data_idx, "].key_or_value  ", "= ", State[data_idx].key_or_value  );
        log("-----------------------------------------");
    }

    // Constrain to have valid JSON (TODO: more is needed)
    // State[DATA_BYTES - 1].next_tree_depth === 0;

    // log("State[", DATA_BYTES, "].tree_depth", "= ", State[DATA_BYTES-1].tree_depth);
    // log("State[", DATA_BYTES, "].parsing_key", "= ", State[DATA_BYTES-1].parsing_key);
    // log("State[", DATA_BYTES, "].inside_key", "= ", State[DATA_BYTES-1].inside_key);
    // log("State[", DATA_BYTES, "].parsing_value", "= ", State[DATA_BYTES-1].parsing_value);
    // log("State[", DATA_BYTES, "].inside_value", "= ", State[DATA_BYTES-1].inside_value);
    log("---");
} 