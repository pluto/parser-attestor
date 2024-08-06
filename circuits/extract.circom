pragma circom 2.1.9;

include "bytes.circom";
include "operators.circom";

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
    Instructions[0].byte             <== dataASCII[0];
    Instructions[0].tree_depth       <== 0;
    Instructions[0].parsing_to_key   <== 0;
    Instructions[0].parsing_to_value <== 0;
    Instructions[0].inside_key       <== 0;
    Instructions[0].inside_value     <== 0;

    for(var data_pointer = 1; data_pointer < DATA_BYTES; data_pointer++) {
        Instructions[i] = Parser();
        Instructions[i].byte             <== dataASCII[data_pointer];
        Instructions[i].tree_depth       <== Instructions[i - 1].tree_depth;
        Instructions[i].parsing_to_key   <== Instructions[i - 1].parsing_to_key;
        Instructions[i].parsing_to_value <== Instructions[i - 1].parsing_to_value;
        Instructions[i].inside_key       <== Instructions[i - 1].inside_key;
        Instructions[i].inside_value     <== Instructions[i - 1].inside_value;
    }
} 