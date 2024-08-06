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
    State[0].parsing_to_key   <== 0;
    State[0].parsing_to_value <== 0;
    State[0].inside_key       <== 0;
    State[0].inside_value     <== 0;
    log("tree_depth[ 0 ] = ", State[0].tree_depth);

    for(var data_pointer = 1; data_pointer < DATA_BYTES; data_pointer++) {
        State[data_pointer] = Parser();
        State[data_pointer].byte             <== data[data_pointer];
        State[data_pointer].tree_depth       <== State[data_pointer - 1].next_tree_depth;
        // TODO: For the next state, we should use `next_`, this is only to make this compile for now.
        State[data_pointer].parsing_to_key   <== State[data_pointer - 1].parsing_to_key;
        State[data_pointer].parsing_to_value <== State[data_pointer - 1].parsing_to_value;
        State[data_pointer].inside_key       <== State[data_pointer - 1].inside_key;
        State[data_pointer].inside_value     <== State[data_pointer - 1].inside_value;

        // Debugging
        log("tree_depth[", data_pointer, "]", "= ", State[data_pointer].tree_depth);
    }

    log("next_tree_depth[", DATA_BYTES -1, "] = ", State[DATA_BYTES -1].next_tree_depth);

} 