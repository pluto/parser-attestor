pragma circom 2.1.9;

include "bytes.circom";
include "operators.circom";
include "parser.circom";

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
    // Initialze the parser
    component State[DATA_BYTES];
    State[0] = Parser();
    State[0].byte             <== data[0];
    State[0].tree_depth       <== 0;
    State[0].escaping         <== 0;
    State[0].parsing_to_key   <== 1; // Initialize by saying we are parsing to the first key
    State[0].parsing_to_value <== 0;
    State[0].inside_key       <== 0;
    State[0].inside_value     <== 0;
    State[0].end_of_kv        <== 0;

    for(var data_pointer = 1; data_pointer < DATA_BYTES; data_pointer++) {
        State[data_pointer] = Parser();
        State[data_pointer].byte             <== data[data_pointer];
        State[data_pointer].tree_depth       <== State[data_pointer - 1].next_tree_depth;
        State[data_pointer].parsing_to_key   <== State[data_pointer - 1].next_parsing_to_key;
        State[data_pointer].inside_key       <== State[data_pointer - 1].next_inside_key;
        State[data_pointer].parsing_to_value <== State[data_pointer - 1].next_parsing_to_value;
        State[data_pointer].inside_value     <== State[data_pointer - 1].next_inside_value;
        State[data_pointer].end_of_kv        <== State[data_pointer - 1].next_end_of_kv;
        // TODO: For the next state, we should use `next_`, this is only to make this compile for now.
        State[data_pointer].escaping         <== State[data_pointer - 1].escaping;


        // Debugging
        log("State[", data_pointer, "].tree_depth", "= ", State[data_pointer].tree_depth);
        log("State[", data_pointer, "].parsing_to_key", "= ", State[data_pointer].parsing_to_key);
        log("State[", data_pointer, "].inside_key", "= ", State[data_pointer].inside_key);
        log("State[", data_pointer, "].parsing_to_value", "= ", State[data_pointer].parsing_to_value);
        log("State[", data_pointer, "].inside_value", "= ", State[data_pointer].inside_value);
        log("State[", data_pointer, "].end_of_kv", "= ", State[data_pointer].end_of_kv);
        log("---");
    }

    // Constrain to have valid JSON (TODO: more is needed)
    State[DATA_BYTES - 1].next_tree_depth === 0;
} 