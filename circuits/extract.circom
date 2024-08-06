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
    component Instructions[DATA_BYTES];
    Instructions[0] = Parser();
    Instructions[0].byte             <== data[0];
    Instructions[0].tree_depth       <== 0;
    Instructions[0].parsing_to_key   <== 0;
    Instructions[0].parsing_to_value <== 0;
    Instructions[0].inside_key       <== 0;
    Instructions[0].inside_value     <== 0;
    log("next_tree_depth[ 0 ] = ", Instructions[0].next_tree_depth);

    for(var data_pointer = 1; data_pointer < DATA_BYTES; data_pointer++) {
        Instructions[data_pointer] = Parser();
        Instructions[data_pointer].byte             <== data[data_pointer];
        Instructions[data_pointer].tree_depth       <== Instructions[data_pointer - 1].tree_depth;
        Instructions[data_pointer].parsing_to_key   <== Instructions[data_pointer - 1].parsing_to_key;
        Instructions[data_pointer].parsing_to_value <== Instructions[data_pointer - 1].parsing_to_value;
        Instructions[data_pointer].inside_key       <== Instructions[data_pointer - 1].inside_key;
        Instructions[data_pointer].inside_value     <== Instructions[data_pointer - 1].inside_value;
        log("next_tree_depth[", data_pointer, "]", "= ", Instructions[data_pointer].next_tree_depth);
    }
} 