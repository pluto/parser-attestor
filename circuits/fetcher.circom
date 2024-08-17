pragma circom 2.1.9;

include "extract.circom";
include "parser.circom";
include "language.circom";
include "utils.circom";
include "circomlib/circuits/mux1.circom";
include "@zk-email/circuits/utils/functions.circom";
include "@zk-email/circuits/utils/array.circom";

template InsideKey(n) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;

    signal parsing_string_or_number <== parsing_string + parsing_number;
    signal if_parsing_key <== current_val[0] * (1-current_val[1]);

    out <== if_parsing_key * parsing_string_or_number;
}

template InsideValue(n) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;

    signal parsing_string_or_number <== parsing_string + parsing_number;
    signal if_parsing_value <== current_val[0] * current_val[1];

    out <== if_parsing_value * parsing_string_or_number;
}

template NextKVPair(n) {
    signal input stack[n][2];
    signal input curr_byte;
    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;

    signal isNextPair <== IsEqualArray(2)([current_val, [1, 1]]);
    signal isComma <== IsEqual()([curr_byte, 44]); // `, -> 44`

    out <== isNextPair * isComma;
}

template KeyMatch(dataLen, keyLen) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal input r;
    signal input index;
    signal input parsing_key;

    signal end_of_key <== IndexSelector(dataLen)(data, index + keyLen);
    signal is_end_of_key_equal_to_quote <== IsEqual()([end_of_key, 34]);

    signal start_of_key <== IndexSelector(dataLen)(data, index - 1);
    signal is_start_of_key_equal_to_quote <== IsEqual()([start_of_key, 34]);

    signal substring_match <== IsSubstringMatchWithIndex(dataLen, keyLen)(data, key, 100, index);

    signal is_key_between_quotes <== is_start_of_key_equal_to_quote * is_end_of_key_equal_to_quote;
    signal is_parsing_correct_key <== is_key_between_quotes * parsing_key;
    // log("key match", index, end_of_key, is_end_of_key_equal_to_quote, substring_match);

    signal output out <== substring_match * is_parsing_correct_key;
}

template ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key[keyLen];

    signal output value[maxValueLen];

    signal mask[DATA_BYTES];
    mask[0] <== 0;

    var logDataLen = log2Ceil(DATA_BYTES);

    component State[DATA_BYTES];
    State[0] = StateUpdate(MAX_STACK_HEIGHT);
    State[0].byte           <== data[0];
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        State[0].stack[i]   <== [0,0];
    }
    State[0].parsing_string <== 0;
    State[0].parsing_number <== 0;

    signal parsing_key[DATA_BYTES];
    signal parsing_value[DATA_BYTES];
    signal is_key_match[DATA_BYTES];
    signal is_key_match_and_inside_key[DATA_BYTES];
    signal is_key_match_for_value[DATA_BYTES];
    is_key_match_for_value[0] <== 0;
    signal value_mask[DATA_BYTES];
    signal is_next_pair[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx, "].stack[", i,"]    ", "= [",State[data_idx].stack[i][0], "][", State[data_idx].stack[i][1],"]" );
        }
        log("State[", data_idx, "].parsing_string", "= ", State[data_idx].parsing_string);
        log("State[", data_idx, "].parsing_number", "= ", State[data_idx].parsing_number);

        parsing_key[data_idx] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing key:", parsing_key[data_idx]);

        parsing_value[data_idx] <== InsideValue(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing value:", parsing_value[data_idx]);

        is_key_match[data_idx] <== KeyMatch(DATA_BYTES, keyLen)(data, key, 100, data_idx, parsing_key[data_idx]);
        // log("is_key_match", is_key_match[data_idx]);

        // is the value getting parsed has a matched key?
        // use mux1 to carry parse_key forward to value
        // is_key_match_for_value should reset when moving to next kv pair
        // `is_key_match = 0` -> 0
        // `is_key_match = 1` -> 1 until new kv pair
        // `new kv pair = 1`  -> 0
        is_next_pair[data_idx] <== NextKVPair(MAX_STACK_HEIGHT)(State[data_idx].stack, data[data_idx]);
        // log("is_new_kv_pair:", is_next_pair[data_idx]);

        is_key_match_for_value[data_idx] <== Mux1()([is_key_match_for_value[data_idx-1] * (1-is_next_pair[data_idx]), is_key_match[data_idx] * (1-is_next_pair[data_idx])], is_key_match[data_idx]);
        // log("is_key_match_for_value:", is_key_match_for_value[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx] <== data[data_idx] * parsing_value[data_idx];
        mask[data_idx] <== value_mask[data_idx] * is_key_match_for_value[data_idx];
        log("mask", mask[data_idx]);


        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }


    signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }

    value <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-1], maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value[i]);
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
}