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

/// Checks if current byte is inside a JSON key or not
///
/// # Arguments
/// - `n`: maximum stack depth
///
/// # Inputs
/// - `stack`: current stack state
/// - `parsing_string`: whether current byte is inside a string or not
/// - `parsing_number`: wheter current byte is inside a number or not
///
/// # Output
/// - `out`: Returns `1` if current byte is inside a key
template InsideKey(n) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal currentVal[2] <== topOfStack.value;

    signal parsingStringAndNotNumber <== parsing_string * (1 - parsing_number);
    signal ifParsingKey <== currentVal[0] * (1-currentVal[1]);

    out <== ifParsingKey * parsingStringAndNotNumber;
}

/// Checks if current byte is inside a JSON value or not
///
/// # Arguments
/// - `n`: maximum stack depth
///
/// # Inputs
/// - `stack`: current stack state
/// - `parsing_string`: whether current byte is inside a string or not
/// - `parsing_number`: wheter current byte is inside a number or not
///
/// # Output
/// - `out`: Returns `1` if current byte is inside a value
template InsideValue(n) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal currentVal[2] <== topOfStack.value;

    signal parsingStringXORNumber <== XOR()(parsing_string, parsing_number);

    signal ifParsingValue <== currentVal[0] * currentVal[1];

    out <== ifParsingValue * parsingStringXORNumber;
}

/// Checks if current byte is inside a JSON value at specified depth
///
/// # Arguments
/// - `n`: maximum stack depth
/// - `depth`: stack height of parsed byte
///
/// # Inputs
/// - `stack`: current stack state
/// - `parsing_string`: whether current byte is inside a string or not
/// - `parsing_number`: wheter current byte is inside a number or not
///
/// # Output
/// - `out`: Returns `1` if current byte is inside a value
template InsideValueAtDepth(n, depth) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    signal ifParsingValue <== stack[depth][0] * stack[depth][1];
    signal parsingStringXORNumber <== XOR()(parsing_string, parsing_number);

    out <== ifParsingValue * parsingStringXORNumber;
}

/// Checks if current byte is inside an array at specified index
///
/// # Arguments
/// - `n`: maximum stack depth
/// - `index`: index of array element
///
/// # Inputs
/// - `stack`: current stack state
/// - `parsing_string`: whether current byte is inside a string or not
/// - `parsing_number`: wheter current byte is inside a number or not
///
/// # Output
/// - `out`: Returns `1` if current byte represents an array element at `index`
template InsideArrayIndex(n, index) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    component topOfStack = GetTopOfStack(n);
    topOfStack.stack <== stack;
    signal currentVal[2] <== topOfStack.value;

    signal insideArray <== IsEqual()([currentVal[0], 2]);
    signal insideIndex <== IsEqual()([currentVal[1], index]);
    signal insideArrayIndex <== insideArray * insideIndex;
    signal parsingStringXORNumber <== XOR()(parsing_string, parsing_number);

    out <== insideArrayIndex * parsingStringXORNumber;
}

/// Checks if current byte is inside an array index at specified depth
///
/// # Arguments
/// - `n`: maximum stack depth
/// - `index`: array element index
/// - `depth`: stack height of parsed byte
///
/// # Inputs
/// - `stack`: current stack state
/// - `parsing_string`: whether current byte is inside a string or not
/// - `parsing_number`: wheter current byte is inside a number or not
///
/// # Output
/// - `out`: Returns `1` if current byte is inside an array index
template InsideArrayIndexAtDepth(n, index, depth) {
    signal input stack[n][2];
    signal input parsing_string;
    signal input parsing_number;

    signal output out;

    signal insideArray <== IsEqual()([stack[depth][0], 2]);
    signal insideIndex <== IsEqual()([stack[depth][1], index]);
    signal insideArrayIndex <== insideArray * insideIndex;
    out <== insideArrayIndex * (parsing_string + parsing_number);
}

/// Returns whether next key-value pair starts.
///
/// # Arguments
/// - `n`: maximum stack depth
///
/// # Inputs
/// - `stack`: current stack state
/// - `curr_byte`: current parsed byte
///
/// # Output
/// - `out`: Returns `1` for next key-value pair.
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

/// Returns whether next key-value pair starts.
/// Checks current byte is at depth greater than specified `depth`.
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
    signal currentVal[2] <== topOfStack.value;
    signal pointer <== topOfStack.pointer;

    signal isNextPair <== IsEqualArray(2)([currentVal, [1, 0]]);

    // `, -> 44`
    signal isComma <== IsEqual()([currByte, 44]);
    // pointer <= depth
    signal atLessDepth <== LessEqThan(logMaxDepth)([pointer, depth]);
    // current depth is less than key depth
    signal isCommaAtDepthLessThanCurrent <== isComma * atLessDepth;

    out <== isNextPair * isCommaAtDepthLessThanCurrent;
}

/// Matches a JSON key at an `index` using Substring Matching
///
/// # Arguments
/// - `dataLen`: parsed data length
/// - `keyLen`: key length
///
/// # Inputs
/// - `data`: data bytes
/// - `key`: key bytes
/// - `r`: random number for substring matching. **Need to be chosen carefully.**
/// - `index`: data index to match from
/// - `parsing_key`: if current byte is inside a key
///
/// # Output
/// - `out`: Returns `1` if `key` matches `data` at `index`
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

    signal substring_match <== SubstringMatchWithIndex(dataLen, keyLen)(data, key, r, index);

    signal is_key_between_quotes <== is_start_of_key_equal_to_quote * is_end_of_key_equal_to_quote;
    signal is_parsing_correct_key <== is_key_between_quotes * parsing_key;

    signal output out <== substring_match * is_parsing_correct_key;
}

/// Matches a JSON key at an `index` using Substring Matching at specified depth
///
/// # Arguments
/// - `dataLen`: parsed data length
/// - `n`: maximum stack height
/// - `keyLen`: key length
/// - `depth`: depth of key to be matched
///
/// # Inputs
/// - `data`: data bytes
/// - `key`: key bytes
/// - `r`: random number for substring matching. **Need to be chosen carefully.**
/// - `index`: data index to match from
/// - `parsing_key`: if current byte is inside a key
/// - `stack`: parser stack output
///
/// # Output
/// - `out`: Returns `1` if `key` matches `data` at `index`
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

    // end of key equals `"`
    signal end_of_key <== IndexSelector(dataLen)(data, index + keyLen);
    signal is_end_of_key_equal_to_quote <== IsEqual()([end_of_key, 34]);

    // start of key equals `"`
    signal start_of_key <== IndexSelector(dataLen)(data, index - 1);
    signal is_start_of_key_equal_to_quote <== IsEqual()([start_of_key, 34]);

    // key matches
    signal substring_match <== SubstringMatchWithIndex(dataLen, keyLen)(data, key, r, index);

    // key should be a string
    signal is_key_between_quotes <== is_start_of_key_equal_to_quote * is_end_of_key_equal_to_quote;

    // is the index given correct?
    signal is_parsing_correct_key <== is_key_between_quotes * parsing_key;
    // is the key given by index at correct depth?
    signal is_key_at_depth <== IsEqual()([pointer-1, depth]);

    signal is_parsing_correct_key_at_depth <== is_parsing_correct_key * is_key_at_depth;
    // log("key match", index, end_of_key, is_end_of_key_equal_to_quote, substring_match);

    signal output out <== substring_match * is_parsing_correct_key_at_depth;
}