pragma circom 2.1.9;

include "extract.circom";
include "parser.circom";
include "language.circom";
include "search.circom";
include "./utils/array.circom";
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
    signal currentVal[2] <== topOfStack.value;

    signal parsingStringOrNumber <== parsing_string + parsing_number;
    signal ifParsingKey <== currentVal[0] * (1-currentVal[1]);

    out <== ifParsingKey * parsingStringOrNumber;
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
    signal input currByte;
    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal currentVal[2] <== topOfStack.value;

    signal isNextPair <== IsEqualArray(2)([currentVal, [1, 0]]);
    signal isComma <== IsEqual()([currByte, 44]); // `, -> 44`

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
    signal input currByte;
    signal output out;

    var logMaxDepth = log2Ceil(n);

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal current_val[2] <== topOfStack.value;
    signal pointer <== topOfStack.pointer;

    signal isNextPair <== IsEqualArray(2)([current_val, [1, 0]]);
    // log("isNextPair", current_val[0], current_val[1], isNextPair);
    signal isComma <== IsEqual()([currByte, 44]); // `, -> 44`
    // log("isComma", isComma, currByte);
    // pointer <= depth
    signal atLessDepth <== LessEqThan(logMaxDepth)([pointer, depth]);
    // log("atLessDepth:", pointer, depth, atLessDepth);
    // current depth is less than key depth
    signal isCommaAtDepthLessThanCurrent <== isComma * atLessDepth;

    out <== isNextPair * isCommaAtDepthLessThanCurrent;
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

    signal substring_match <== SubstringMatchWithIndex(dataLen, keyLen)(data, key, 100, index);

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

    signal substring_match <== SubstringMatchWithIndex(dataLen, keyLen)(data, key, 100, index);

    signal is_key_between_quotes <== is_start_of_key_equal_to_quote * is_end_of_key_equal_to_quote;
    // log("key pointer", pointer, depth);
    signal is_parsing_correct_key <== is_key_between_quotes * parsing_key;
    signal is_key_at_depth <== IsEqual()([pointer-1, depth]);
    signal is_parsing_correct_key_at_depth <== is_parsing_correct_key * is_key_at_depth;
    // log("key match", index, end_of_key, is_end_of_key_equal_to_quote, substring_match);

    signal output out <== substring_match * is_parsing_correct_key_at_depth;
}