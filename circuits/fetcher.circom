pragma circom 2.1.9;

include "extract.circom";
include "parser.circom";
include "language.circom";
include "utils.circom";
include "circomlib/circuits/mux1.circom";
include "circomlib/circuits/gates.circom";
include "@zk-email/circuits/utils/functions.circom";
include "@zk-email/circuits/utils/array.circom";

// TODOs:
// - remove use of random_signal in key match from 100
//

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

template InsideObjectAtDepth(n, depth) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    signal if_parsing_value <== stack[depth][0] * stack[depth][1];

    out <== if_parsing_value * (parsing_string + parsing_number);
}

template InsideArrayIndex(n, index) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;

    signal inside_array <== IsEqual()([current_val[0], 2]);
    signal inside_index <== IsEqual()([current_val[1], index]);
    signal inside_array_index <== inside_array * inside_index;
    out <== inside_array_index * (parsing_string + parsing_number);
}

template InsideArrayIndexAtDepth(n, index, depth) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    signal inside_array <== IsEqual()([stack[depth][0], 2]);
    signal inside_index <== IsEqual()([stack[depth][1], index]);
    signal inside_array_index <== inside_array * inside_index;
    out <== inside_array_index * (parsing_string + parsing_number);
}

template NextKVPair(n) {
    signal input stack[n][2];
    signal input curr_byte;
    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;

    signal isNextPair <== IsEqualArray(2)([current_val, [1, 0]]);
    signal isComma <== IsEqual()([curr_byte, 44]); // `, -> 44`

    out <== isNextPair*isComma ;
}

/// Checks current byte is at depth greater than specified `depth`
/// and returns whether next key-value pair starts.
///
/// # Arguments
/// - `n`: maximum stack depth
/// - `depth`: depth of matched key-value pair
///
/// # Inputs
/// - `stack`: current stack state
/// - `curr_byte`: current parsed byte
///
/// # Output
/// - `out`: Returns `1` for next key-value pair at specified depth.
template NextKVPairAtDepth(n, depth) {
    signal input stack[n][2];
    signal input curr_byte;
    signal output out;

    var log_max_depth = log2Ceil(n);

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;
    signal pointer <== topOfStack.pointer;

    signal isNextPair <== IsEqualArray(2)([current_val, [1, 0]]);
    signal isComma <== IsEqual()([curr_byte, 44]); // `, -> 44`
    // pointer <= depth
    signal atLessDepth <== LessEqThan(log_max_depth)([pointer, depth]);
    // current depth is less than key depth
    signal is_comma_at_depth_less_than_current <== isComma * atLessDepth;

    out <== isNextPair*is_comma_at_depth_less_than_current;
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

template KeyMatchAtDepth(dataLen, n, keyLen, depth) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal input r;
    signal input index;
    signal input parsing_key;
    signal input stack[n][2];

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal pointer <== topOfStack.pointer;

    signal end_of_key <== IndexSelector(dataLen)(data, index + keyLen);
    signal is_end_of_key_equal_to_quote <== IsEqual()([end_of_key, 34]);

    signal start_of_key <== IndexSelector(dataLen)(data, index - 1);
    signal is_start_of_key_equal_to_quote <== IsEqual()([start_of_key, 34]);

    signal substring_match <== IsSubstringMatchWithIndex(dataLen, keyLen)(data, key, 100, index);

    signal is_key_between_quotes <== is_start_of_key_equal_to_quote * is_end_of_key_equal_to_quote;
    log("key pointer", pointer, depth);
    signal is_parsing_correct_key <== is_key_between_quotes * parsing_key;
    signal is_key_at_depth <== IsEqual()([pointer-1, depth]);
    signal is_parsing_correct_key_at_depth <== is_parsing_correct_key * is_key_at_depth;
    // log("key match", index, end_of_key, is_end_of_key_equal_to_quote, substring_match);

    signal output out <== substring_match * is_parsing_correct_key_at_depth;
}

template ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key[keyLen];

    signal output value_starting_index[DATA_BYTES];

    signal mask[DATA_BYTES];
    // mask[0] <== 0;

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
    is_key_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal value_mask[DATA_BYTES];
    signal is_next_pair[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);

        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        log("parsing key:", parsing_key[data_idx-1]);

        parsing_value[data_idx-1] <== InsideValue(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        log("parsing value:", parsing_value[data_idx-1]);

        is_key_match[data_idx-1] <== KeyMatch(DATA_BYTES, keyLen)(data, key, 100, data_idx-1, parsing_key[data_idx-1]);
        log("is_key_match", is_key_match[data_idx-1]);

        // is the value getting parsed has a matched key?
        // use mux1 to carry parse_key forward to value
        // is_key_match_for_value should reset when moving to next kv pair
        // `is_key_match = 0` -> 0
        // `is_key_match = 1` -> 1 until new kv pair
        // `new kv pair = 1`  -> 0
        is_next_pair[data_idx-1] <== NextKVPair(MAX_STACK_HEIGHT)(State[data_idx].stack, data[data_idx-1]);
        // log("is_new_kv_pair:", is_next_pair[data_idx-1]);

        is_key_match_for_value[data_idx] <== Mux1()([is_key_match_for_value[data_idx-1] * (1-is_next_pair[data_idx-1]), is_key_match[data_idx-1] * (1-is_next_pair[data_idx-1])], is_key_match[data_idx-1]);
        log("is_key_match_for_value:", is_key_match_for_value[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_key_match_for_value[data_idx];
        log("mask", mask[data_idx-1]);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }
}

template ExtractString(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key[keyLen];

    signal output value[maxValueLen];

    signal value_starting_index[DATA_BYTES];

    value_starting_index <== ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, maxValueLen)(data, key);

    value <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2]+1, maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value[i]);
    }
}

template ExtractNumber(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key[keyLen];

    signal value_string[maxValueLen];
    signal output value;

    signal value_starting_index[DATA_BYTES];

    value_starting_index <== ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, maxValueLen)(data, key);

    value_string <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2], maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value_string[i]);
    }

    signal number_value[maxValueLen];
    number_value[0] <== (value_string[0]-48);
    for (var i=1 ; i<maxValueLen ; i++) {
        number_value[i] <== number_value[i-1] * 10 + (value_string[i]-48);
    }

    value <== number_value[maxValueLen-1];
}

template ExtractArray(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, index, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key[keyLen];

    signal value_starting_index[DATA_BYTES];
    signal output value[maxValueLen];


    signal mask[DATA_BYTES];
    // mask[0] <== 0;

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
    is_key_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal value_mask[DATA_BYTES];
    signal is_next_pair[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);

        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing key:", parsing_key[data_idx]);

        parsing_value[data_idx-1] <== InsideArrayIndex(MAX_STACK_HEIGHT, index)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing value:", parsing_value[data_idx]);

        is_key_match[data_idx-1] <== KeyMatch(DATA_BYTES, keyLen)(data, key, 100, data_idx-1, parsing_key[data_idx-1]);
        // log("is_key_match", is_key_match[data_idx]);

        // is the value getting parsed has a matched key?
        // use mux1 to carry parse_key forward to value
        // is_key_match_for_value should reset when moving to next kv pair
        // `is_key_match = 0` -> 0
        // `is_key_match = 1` -> 1 until new kv pair
        // `new kv pair = 1`  -> 0
        is_next_pair[data_idx-1] <== NextKVPair(MAX_STACK_HEIGHT)(State[data_idx].stack, data[data_idx-1]);
        // log("is_new_kv_pair:", is_next_pair[data_idx]);

        is_key_match_for_value[data_idx] <== Mux1()([is_key_match_for_value[data_idx-1] * (1-is_next_pair[data_idx-1]), is_key_match[data_idx-1] * (1-is_next_pair[data_idx-1])], is_key_match[data_idx-1]);
        // log("is_key_match_for_value:", is_key_match_for_value[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_key_match_for_value[data_idx];
        log("mask", mask[data_idx-1]);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }

    signal value_string[maxValueLen];

    value_string <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2]+1, maxValueLen);

    // for (var i=0 ; i<maxValueLen; i++) {
        // log("value[",i,"]=", value_string[i]);
        // value[i-1] <== value_string[i];
    // }

    value <== value_string;

    // signal number_value[maxValueLen];
    // number_value[0] <== (value_string[0]-48);
    // for (var i=1 ; i<maxValueLen ; i++) {
    //     number_value[i] <== number_value[i-1] * 10 + (value_string[i]-48);
    // }

    // value <== number_value[maxValueLen-1];
}

template ExtractMultiDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, maxValueLen) {
    signal input data[DATA_BYTES];

    signal input key1[keyLen1];
    signal input key2[keyLen2];

    signal output value_starting_index[DATA_BYTES];

    signal mask[DATA_BYTES];
    // mask[0] <== 0;

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
    signal is_key1_match[DATA_BYTES];
    signal is_key2_match[DATA_BYTES];
    signal is_key1_match_for_value[DATA_BYTES];
    is_key1_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal is_key2_match_for_value[DATA_BYTES];
    is_key2_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal is_value_match[DATA_BYTES];
    is_value_match[0] <== 0;
    signal value_mask[DATA_BYTES];
    signal is_next_pair_at_depth1[DATA_BYTES];
    signal is_next_pair_at_depth2[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);

        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        // - parsing key
        // - parsing value (different for string/numbers and array)
        // - key match (key 1, key 2)
        // - is next pair
        // - is key match for value
        // - value_mask
        // - mask

        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing key:", parsing_key[data_idx]);

        parsing_value[data_idx-1] <== InsideValue(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing value:", parsing_value[data_idx]);

        is_key1_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1)(data, key1, 100, data_idx-1, parsing_key[data_idx-1], State[data_idx].stack);
        is_key2_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen2, depth2)(data, key2, 100, data_idx-1, parsing_key[data_idx-1], State[data_idx].stack);
        // log("is_key_match", is_key1_match[data_idx-1], is_key2_match[data_idx-1]);

        // is_next_pair represents if we are currently parsing kv pair of depth greater than key's depth
        // eg: `{ "a": { "d" : "e", "e": "c" }, "e": { "f": "a", "e": "2" } }`
        is_next_pair_at_depth1[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth1)(State[data_idx].stack, data[data_idx-1]);
        is_next_pair_at_depth2[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth2)(State[data_idx].stack, data[data_idx-1]);
        // log("is_new_kv_pair:", is_next_pair_at_depth1[data_idx-1], is_next_pair_at_depth2[data_idx-1]);

        // is the value getting parsed has a matched key?
        // use mux1 to carry parse_key forward to value
        // is_key_match_for_value should reset when moving to next kv pair
        // `is_key_match = 0` -> 0
        // `is_key_match = 1` -> 1 until new kv pair
        // `new kv pair = 1`  -> 0
        // all the keys should match for the correct value
        is_key1_match_for_value[data_idx] <== Mux1()([is_key1_match_for_value[data_idx-1] * (1-is_next_pair_at_depth1[data_idx-1]), is_key1_match[data_idx-1] * (1-is_next_pair_at_depth1[data_idx-1])], is_key1_match[data_idx-1]);
        is_key2_match_for_value[data_idx] <== Mux1()([is_key2_match_for_value[data_idx-1] * (1-is_next_pair_at_depth2[data_idx-1]), is_key2_match[data_idx-1] * (1-is_next_pair_at_depth2[data_idx-1])], is_key2_match[data_idx-1]);
        // log("is_key_match_for_value:", is_key1_match_for_value[data_idx], is_key2_match_for_value[data_idx]);

        is_value_match[data_idx] <== is_key1_match_for_value[data_idx] * is_key2_match_for_value[data_idx];
        // log("is_value_match", is_value_match[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_value_match[data_idx];
        log("mask", mask[data_idx-1]);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }
}

template ExtractStringMultiDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key1[keyLen1];
    signal input key2[keyLen2];

    signal output value[maxValueLen];

    signal value_starting_index[DATA_BYTES];

    value_starting_index <== ExtractMultiDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, maxValueLen)(data, key1, key2);

    log(value_starting_index[DATA_BYTES-2]);

    value <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2]+1, maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value[i]);
    }
}

template ExtractNestedArray(DATA_BYTES, MAX_STACK_HEIGHT, keyLen, index1, depth1, index2, depth2, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key[keyLen];

    signal value_starting_index[DATA_BYTES];
    signal output value[maxValueLen];


    signal mask[DATA_BYTES];
    // mask[0] <== 0;

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
    signal parsing_array1[DATA_BYTES];
    signal parsing_array2[DATA_BYTES];
    signal parsing_value[DATA_BYTES];
    signal is_key_match[DATA_BYTES];
    signal is_key_match_and_inside_key[DATA_BYTES];
    signal is_key_match_for_value[DATA_BYTES];
    is_key_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal value_mask[DATA_BYTES];
    signal is_next_pair[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);

        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing key:", parsing_key[data_idx]);

        parsing_array1[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index1, depth1)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        parsing_array2[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index2, depth2)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        parsing_value[data_idx-1] <== parsing_array1[data_idx-1] * parsing_array2[data_idx-1];
        log("parsing value:", parsing_value[data_idx-1]);

        is_key_match[data_idx-1] <== KeyMatch(DATA_BYTES, keyLen)(data, key, 100, data_idx-1, parsing_key[data_idx-1]);
        // log("is_key_match", is_key_match[data_idx]);

        // is the value getting parsed has a matched key?
        // use mux1 to carry parse_key forward to value
        // is_key_match_for_value should reset when moving to next kv pair
        // `is_key_match = 0` -> 0
        // `is_key_match = 1` -> 1 until new kv pair
        // `new kv pair = 1`  -> 0
        is_next_pair[data_idx-1] <== NextKVPair(MAX_STACK_HEIGHT)(State[data_idx].stack, data[data_idx-1]);
        // log("is_new_kv_pair:", is_next_pair[data_idx]);

        is_key_match_for_value[data_idx] <== Mux1()([is_key_match_for_value[data_idx-1] * (1-is_next_pair[data_idx-1]), is_key_match[data_idx-1] * (1-is_next_pair[data_idx-1])], is_key_match[data_idx-1]);
        // log("is_key_match_for_value:", is_key_match_for_value[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_key_match_for_value[data_idx];
        log("mask", mask[data_idx-1]);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }

    signal value_string[maxValueLen];

    log("value_starting_index:", value_starting_index[DATA_BYTES-2]);

    value_string <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2], maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value_string[i]);
    }

    value <== value_string;

    // signal number_value[maxValueLen];
    // number_value[0] <== (value_string[0]-48);
    // for (var i=1 ; i<maxValueLen ; i++) {
    //     number_value[i] <== number_value[i-1] * 10 + (value_string[i]-48);
    // }

    // value <== number_value[maxValueLen-1];
}

template ExtractMultiDepthNestedObject(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen) {
    signal input data[DATA_BYTES];

    signal input key1[keyLen1];
    signal input key2[keyLen2];

    signal output value_starting_index[DATA_BYTES];

    signal mask[DATA_BYTES];
    // mask[0] <== 0;

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
    signal parsing_object1_value[DATA_BYTES];
    signal parsing_object2_value[DATA_BYTES];
    signal parsing_array1[DATA_BYTES];
    signal parsing_array2[DATA_BYTES];
    signal is_key1_match[DATA_BYTES];
    signal is_key2_match[DATA_BYTES];
    signal is_key1_match_for_value[DATA_BYTES];
    is_key1_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal is_key2_match_for_value[DATA_BYTES];
    is_key2_match_for_value[0] <== 0; // TODO: this might not be correct way to initialise
    signal is_value_match[DATA_BYTES];
    is_value_match[0] <== 0;
    signal value_mask[DATA_BYTES];
    signal is_next_pair_at_depth1[DATA_BYTES];
    signal is_next_pair_at_depth2[DATA_BYTES];
    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);

        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        // - parsing key
        // - parsing value (different for string/numbers and array)
        // - key match (key 1, key 2)
        // - is next pair
        // - is key match for value
        // - value_mask
        // - mask

        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // log("parsing key:", parsing_key[data_idx]);

        parsing_array1[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index3, depth3)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        parsing_array2[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index4, depth4)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        // parsing_value[data_idx-1] <== parsing_array1[data_idx-1] * parsing_array2[data_idx-1];

        parsing_object1_value[data_idx-1] <== InsideObjectAtDepth(MAX_STACK_HEIGHT, depth1)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        parsing_object2_value[data_idx-1] <== InsideObjectAtDepth(MAX_STACK_HEIGHT, depth2)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
        parsing_value[data_idx-1] <== MultiAND(4)([parsing_array1[data_idx-1], parsing_array2[data_idx-1], parsing_object1_value[data_idx-1], parsing_object2_value[data_idx-1]]);
        log("parsing value:", parsing_array1[data_idx-1], parsing_array2[data_idx-1], parsing_object1_value[data_idx-1], parsing_object2_value[data_idx-1], parsing_value[data_idx-1]);

        is_key1_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1)(data, key1, 100, data_idx-1, parsing_key[data_idx-1], State[data_idx].stack);
        is_key2_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen2, depth2)(data, key2, 100, data_idx-1, parsing_key[data_idx-1], State[data_idx].stack);
        log("is_key_match", is_key1_match[data_idx-1], is_key2_match[data_idx-1]);

        // is_next_pair represents if we are currently parsing kv pair of depth greater than key's depth
        // eg: `{ "a": { "d" : "e", "e": "c" }, "e": { "f": "a", "e": "2" } }`
        is_next_pair_at_depth1[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth1)(State[data_idx].stack, data[data_idx-1]);
        is_next_pair_at_depth2[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth2)(State[data_idx].stack, data[data_idx-1]);
        log("is_new_kv_pair:", is_next_pair_at_depth1[data_idx-1], is_next_pair_at_depth2[data_idx-1]);

        // is the value getting parsed has a matched key?
        // use mux1 to carry parse_key forward to value
        // is_key_match_for_value should reset when moving to next kv pair
        // `is_key_match = 0` -> 0
        // `is_key_match = 1` -> 1 until new kv pair
        // `new kv pair = 1`  -> 0
        // all the keys should match for the correct value
        is_key1_match_for_value[data_idx] <== Mux1()([is_key1_match_for_value[data_idx-1] * (1-is_next_pair_at_depth1[data_idx-1]), is_key1_match[data_idx-1] * (1-is_next_pair_at_depth1[data_idx-1])], is_key1_match[data_idx-1]);
        is_key2_match_for_value[data_idx] <== Mux1()([is_key2_match_for_value[data_idx-1] * (1-is_next_pair_at_depth2[data_idx-1]), is_key2_match[data_idx-1] * (1-is_next_pair_at_depth2[data_idx-1])], is_key2_match[data_idx-1]);
        log("is_key_match_for_value:", is_key1_match_for_value[data_idx], is_key2_match_for_value[data_idx]);

        is_value_match[data_idx] <== is_key1_match_for_value[data_idx] * is_key2_match_for_value[data_idx];
        // log("is_value_match", is_value_match[data_idx]);

        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_value_match[data_idx];
        log("mask", mask[data_idx-1]);
        log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    }

    // Debugging
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

    // signal value_starting_index[DATA_BYTES];
    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }
}

template ExtractStringMultiDepthNested(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen) {
    signal input data[DATA_BYTES];
    signal input key1[keyLen1];
    signal input key2[keyLen2];

    signal output value[maxValueLen];

    signal value_starting_index[DATA_BYTES];

    value_starting_index <== ExtractMultiDepthNestedObject(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen)(data, key1, key2);

    log("value_starting_index", value_starting_index[DATA_BYTES-2]);
    // TODO: why +1 not required here,when required on all other string implss?
    value <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2], maxValueLen);

    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value[i]);
    }
}