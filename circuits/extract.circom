pragma circom 2.1.9;

include "utils.circom";
include "parser.circom";

template Extract(DATA_BYTES, MAX_STACK_HEIGHT) {
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
    State[0] = StateUpdate(MAX_STACK_HEIGHT);
    State[0].byte           <== data[0];
    State[0].pointer        <== 0;
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        State[0].stack[i]   <== 0;
    }
    // State[0].stack          <== [0,0,0,0,0,0,0,0,0,0,0,0];
    State[0].parsing_string <== 0;
    State[0].parsing_number <== 0;

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].pointer        <== State[data_idx - 1].next_pointer;
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        // Debugging
        log("State[", data_idx, "].pointer       ", "= ", State[data_idx].pointer);
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx, "].stack[", i,"]    ", "= ", State[data_idx].stack[i]);
        }
        log("State[", data_idx, "].parsing_string", "= ", State[data_idx].parsing_string);
        log("State[", data_idx, "].parsing_number", "= ", State[data_idx].parsing_number);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Constrain to have valid JSON (TODO: more is needed)
    // State[DATA_BYTES - 1].next_tree_depth === 0;

        // Debugging
        log("State[", DATA_BYTES, "].pointer       ", "= ", State[DATA_BYTES -1].next_pointer);
        for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
            log("State[", DATA_BYTES, "].stack[", i,"]    ", "= ", State[DATA_BYTES -1 ].next_stack[i]);
        }
        log("State[", DATA_BYTES, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
        log("State[", DATA_BYTES, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
} 