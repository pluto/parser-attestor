pragma circom 2.1.9;

include "interpreter.circom";
include "parser/machine.circom";
include "../utils/bytes.circom";
include "../utils/search.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/array.circom";

template LockRequestLineData(DATA_BYTES, methodLen, targetLen, versionLen) {
    signal input data[DATA_BYTES];
    signal input method[methodLen];
    signal input target[targetLen];
    signal input version[versionLen];

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
    State[0].parsing_start  <== 1;
    State[0].parsing_header <== 0;
    State[0].parsing_field_name <== 0;
    State[0].parsing_field_value <== 0;
    State[0].parsing_body   <== 0;
    State[0].line_status    <== 0;

    // Check first method byte
    signal methodIsEqual[methodLen];
    methodIsEqual[0] <== IsEqual()([data[0],method[0]]);
    methodIsEqual[0] === 1;

    // Setup to check target bytes
    signal startLineMask[DATA_BYTES];
    signal targetMask[DATA_BYTES];
    signal versionMask[DATA_BYTES];

    var target_start_counter = 1;
    var target_end_counter = 1;
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate();
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].parsing_start  <== State[data_idx - 1].next_parsing_start;
        State[data_idx].parsing_header <== State[data_idx - 1].next_parsing_header;
        State[data_idx].parsing_field_name <== State[data_idx-1].next_parsing_field_name;
        State[data_idx].parsing_field_value <== State[data_idx-1].next_parsing_field_value;
        State[data_idx].parsing_body   <== State[data_idx - 1].next_parsing_body;
        State[data_idx].line_status    <== State[data_idx - 1].next_line_status;
        
        // Check remaining method bytes
        if(data_idx < methodLen) {
            methodIsEqual[data_idx] <== IsEqual()([data[data_idx], method[data_idx]]);
            methodIsEqual[data_idx] === 1;
        }

        // Target
        startLineMask[data_idx] <== inStartLine()(State[data_idx].parsing_start);
        targetMask[data_idx] <==  inTarget()(State[data_idx].parsing_start);
        versionMask[data_idx] <== inVersion()(State[data_idx].parsing_start);
        target_start_counter += startLineMask[data_idx] - targetMask[data_idx] - versionMask[data_idx];
        target_end_counter += startLineMask[data_idx] - versionMask[data_idx];

        // Debugging
        log("State[", data_idx, "].parsing_start       = ", State[data_idx].parsing_start);
        log("State[", data_idx, "].parsing_header      = ", State[data_idx].parsing_header);
        log("State[", data_idx, "].parsing_field_name  = ", State[data_idx].parsing_field_name);
        log("State[", data_idx, "].parsing_field_value = ", State[data_idx].parsing_field_value);
        log("State[", data_idx, "].parsing_body        = ", State[data_idx].parsing_body);
        log("State[", data_idx, "].line_status         = ", State[data_idx].line_status);
        log("------------------------------------------------");
        log("target_start_counter                      = ", target_start_counter);
        log("target_end_counter                        = ", target_end_counter);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    } 

    // Debugging
    log("State[", DATA_BYTES, "].parsing_start      ", "= ", State[DATA_BYTES-1].next_parsing_start);
    log("State[", DATA_BYTES, "].parsing_header     ", "= ", State[DATA_BYTES-1].next_parsing_header);
    log("State[", DATA_BYTES, "].parsing_field_name ", "= ", State[DATA_BYTES-1].parsing_field_name);
    log("State[", DATA_BYTES, "].parsing_field_value", "= ", State[DATA_BYTES-1].parsing_field_value);
    log("State[", DATA_BYTES, "].parsing_body       ", "= ", State[DATA_BYTES-1].next_parsing_body);
    log("State[", DATA_BYTES, "].line_status        ", "= ", State[DATA_BYTES-1].next_line_status);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // Check target is correct by substring match and length check
    signal targetMatch <== SubstringMatchWithIndex(DATA_BYTES, targetLen)(data, target, 100, target_start_counter);
    targetMatch === 1;
    signal targetIsCorrectLength <== IsEqual()([targetLen, target_end_counter - target_start_counter - 1]);
    targetIsCorrectLength === 1;
}