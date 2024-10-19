pragma circom 2.1.9;

include "../interpreter.circom";

template JsonMaskObjectNIVC(DATA_BYTES, MAX_STACK_HEIGHT, MAX_KEY_LENGTH) {
    // ------------------------------------------------------------------------------------------------------------------ //
    // ~~ Set sizes at compile time ~~
    // Total number of variables in the parser for each byte of data
    assert(MAX_STACK_HEIGHT >= 2);
    var PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;
    var TOTAL_BYTES_ACROSS_NIVC   = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1; 
    // ------------------------------------------------------------------------------------------------------------------ //

    // ------------------------------------------------------------------------------------------------------------------ //
    // ~ Unravel from previous NIVC step ~
    // Read in from previous NIVC step (JsonParseNIVC)
    signal input step_in[TOTAL_BYTES_ACROSS_NIVC]; 

    // Grab the raw data bytes from the `step_in` variable
    signal data[DATA_BYTES];
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        data[i] <== step_in[i];
    }

    // Decode the encoded data in `step_in` back into parser variables
    signal stack[DATA_BYTES][MAX_STACK_HEIGHT][2];
    signal parsingData[DATA_BYTES][2];
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        for (var j = 0 ; j < MAX_STACK_HEIGHT ; j++) {
            stack[i][j][0] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + j * 2];
            stack[i][j][1] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + j * 2 + 1];
        }
        parsingData[i][0] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + MAX_STACK_HEIGHT * 2];
        parsingData[i][1] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + MAX_STACK_HEIGHT * 2 + 1];
    }
    // ------------------------------------------------------------------------------------------------------------------ //

    // ------------------------------------------------------------------------------------------------------------------ //
    // ~ Object masking ~
    // Key data to use to point to which object to extract
    signal input key[MAX_KEY_LENGTH];
    signal input keyLen;

    // flag determining whether this byte is matched value
    signal is_value_match[DATA_BYTES - MAX_KEY_LENGTH];
    // final mask
    signal mask[DATA_BYTES - MAX_KEY_LENGTH];

    // signal parsing_object_value[DATA_BYTES - MAX_KEY_LENGTH];
    signal is_key_match[DATA_BYTES - MAX_KEY_LENGTH];
    signal is_key_match_for_value[DATA_BYTES + 1 - MAX_KEY_LENGTH];
    is_key_match_for_value[0] <== 0;
    signal is_next_pair_at_depth[DATA_BYTES - MAX_KEY_LENGTH];

    // Signals to detect if we are parsing a key or value with initial setup
    signal parsing_key[DATA_BYTES - MAX_KEY_LENGTH];
    signal parsing_value[DATA_BYTES - MAX_KEY_LENGTH];

    // Initialize values knowing 0th bit of data will never be a key/value
    parsing_key[0]   <== 0;
    parsing_value[0] <== 0;
    is_key_match[0]  <== 0; 

    component stackSelector[DATA_BYTES];
    stackSelector[0] = ArraySelector(MAX_STACK_HEIGHT, 2);
    stackSelector[0].in <== stack[0];
    stackSelector[0].index <== step_in[TOTAL_BYTES_ACROSS_NIVC - 1];

    is_next_pair_at_depth[0]  <== NextKVPairAtDepth(MAX_STACK_HEIGHT)(stack[0], data[0],step_in[TOTAL_BYTES_ACROSS_NIVC - 1]);
    is_key_match_for_value[1] <== Mux1()([is_key_match_for_value[0] * (1-is_next_pair_at_depth[0]), is_key_match[0] * (1-is_next_pair_at_depth[0])], is_key_match[0]);
    is_value_match[0]         <== parsing_value[0] * is_key_match_for_value[1];

    mask[0] <== data[0] * is_value_match[0];

    for(var data_idx = 1; data_idx < DATA_BYTES - MAX_KEY_LENGTH; data_idx++) {
        stackSelector[data_idx] = ArraySelector(MAX_STACK_HEIGHT, 2);
        stackSelector[data_idx].in <== stack[data_idx];
        stackSelector[data_idx].index <== step_in[TOTAL_BYTES_ACROSS_NIVC - 1];
        parsing_key[data_idx] <== InsideKey()(stackSelector[data_idx].out, parsingData[data_idx][0], parsingData[data_idx][1]);
        parsing_value[data_idx] <== InsideValueObject()(stackSelector[data_idx].out, stack[data_idx][1], parsingData[data_idx][0], parsingData[data_idx][1]);

        // to get correct value, check:
        // - key matches at current index and depth of key is as specified
        // - whether next KV pair starts
        // - whether key matched for a value (propogate key match until new KV pair of lower depth starts)
        is_key_match[data_idx] <== KeyMatchAtIndex(DATA_BYTES, MAX_KEY_LENGTH, data_idx)(data, key, keyLen, parsing_key[data_idx]);
        is_next_pair_at_depth[data_idx] <== NextKVPairAtDepth(MAX_STACK_HEIGHT)(stack[data_idx], data[data_idx], step_in[TOTAL_BYTES_ACROSS_NIVC - 1]);
        is_key_match_for_value[data_idx+1] <== Mux1()([is_key_match_for_value[data_idx] * (1-is_next_pair_at_depth[data_idx]), is_key_match[data_idx] * (1-is_next_pair_at_depth[data_idx])], is_key_match[data_idx]);
        is_value_match[data_idx] <== is_key_match_for_value[data_idx+1] * parsing_value[data_idx];

        // mask = currently parsing value and all subsequent keys matched
        mask[data_idx] <== data[data_idx] * is_value_match[data_idx];

    }

    // Write the `step_out` with masked data
    signal output step_out[TOTAL_BYTES_ACROSS_NIVC];
    for (var i = 0 ; i < DATA_BYTES - MAX_KEY_LENGTH ; i++) {
        step_out[i] <== mask[i];
    }
    for (var i = 0 ; i < MAX_KEY_LENGTH ; i++) {
        step_out[DATA_BYTES - MAX_KEY_LENGTH + i] <== 0;
    }
    // Append the parser state back on `step_out`
    for (var i = DATA_BYTES ; i < TOTAL_BYTES_ACROSS_NIVC - 1 ; i++) {
        step_out[i] <== step_in[i];
    }
    // No need to pad as this is currently when TOTAL_BYTES == TOTAL_BYTES_USED

    // Finally, update the current depth we are extracting from
    step_out[TOTAL_BYTES_ACROSS_NIVC - 1] <== step_in[TOTAL_BYTES_ACROSS_NIVC - 1] + 1;
}

template JsonMaskArrayIndexNIVC(TOTAL_BYTES, DATA_BYTES, MAX_STACK_HEIGHT) {
    // ------------------------------------------------------------------------------------------------------------------ //
    // ~~ Set sizes at compile time ~~
    // Total number of variables in the parser for each byte of data
    assert(MAX_STACK_HEIGHT >= 2);
    var PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;
    var TOTAL_BYTES_USED          = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1);
    // ------------------------------------------------------------------------------------------------------------------ //

    // ------------------------------------------------------------------------------------------------------------------ //
    // ~ Unravel from previous NIVC step ~
    // Read in from previous NIVC step (JsonParseNIVC)
    signal input step_in[TOTAL_BYTES + 1]; // ADD 1 FOR CURRENT STACK POINTER

    // Grab the raw data bytes from the `step_in` variable
    signal data[DATA_BYTES];
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        data[i] <== step_in[i];
    }

    // Decode the encoded data in `step_in` back into parser variables
    signal stack[DATA_BYTES][MAX_STACK_HEIGHT][2];
    signal parsingData[DATA_BYTES][2];
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        for (var j = 0 ; j < MAX_STACK_HEIGHT ; j++) {
            stack[i][j][0] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + j * 2];
            stack[i][j][1] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + j * 2 + 1];
        }
        parsingData[i][0] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + MAX_STACK_HEIGHT * 2];
        parsingData[i][1] <== step_in[DATA_BYTES + i * PER_ITERATION_DATA_LENGTH + MAX_STACK_HEIGHT * 2 + 1];
    }
    // ------------------------------------------------------------------------------------------------------------------ //

    // ------------------------------------------------------------------------------------------------------------------ //
    // ~ Array index masking ~
    signal input index;

    // value starting index in `data`
    signal value_starting_index[DATA_BYTES];
    signal mask[DATA_BYTES];

    signal parsing_array[DATA_BYTES];
    signal or[DATA_BYTES];

    component stackSelector[DATA_BYTES];
    stackSelector[0] = ArraySelector(MAX_STACK_HEIGHT, 2);
    stackSelector[0].in <== stack[0];
    stackSelector[0].index <== step_in[TOTAL_BYTES];

    component nextStackSelector[DATA_BYTES];
    nextStackSelector[0]   = ArraySelector(MAX_STACK_HEIGHT, 2);
    nextStackSelector[0].in    <== stack[0];
    nextStackSelector[0].index <== step_in[TOTAL_BYTES] + 1;

    parsing_array[0] <== InsideArrayIndexObject()(stackSelector[0].out, nextStackSelector[0].out, parsingData[0][0], parsingData[0][1], index);
    mask[0]          <== data[0] * parsing_array[0];

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {
        stackSelector[data_idx]       = ArraySelector(MAX_STACK_HEIGHT, 2);
        stackSelector[data_idx].in    <== stack[data_idx];
        stackSelector[data_idx].index <== step_in[TOTAL_BYTES];

        nextStackSelector[data_idx]       = ArraySelector(MAX_STACK_HEIGHT, 2);
        nextStackSelector[data_idx].in    <== stack[data_idx];
        nextStackSelector[data_idx].index <== step_in[TOTAL_BYTES] + 1;

        parsing_array[data_idx] <== InsideArrayIndexObject()(stackSelector[data_idx].out, nextStackSelector[data_idx].out, parsingData[data_idx][0], parsingData[data_idx][1], index);

        or[data_idx] <== OR()(parsing_array[data_idx], parsing_array[data_idx - 1]);
        mask[data_idx] <== data[data_idx] * or[data_idx];
    }

    // Write the `step_out` with masked data
    signal output step_out[TOTAL_BYTES + 1];
    for (var i = 0 ; i < DATA_BYTES ; i++) {
        step_out[i] <== mask[i];
    }
    // Append the parser state back on `step_out`
    for (var i = DATA_BYTES ; i < TOTAL_BYTES ; i++) {
        step_out[i] <== step_in[i];
    }
    // No need to pad as this is currently when TOTAL_BYTES == TOTAL_BYTES_USED
    step_out[TOTAL_BYTES] <== step_in[TOTAL_BYTES] + 1;
}

template ArraySelector(m, n) {
    signal input in[m][n];
    signal input index;
    signal output out[n];
    assert(index >= 0 && index < m);

    signal selector[m];
    component Equal[m];
    for (var i = 0; i < m; i++) {
        selector[i] <== IsEqual()([index, i]);
    }

    var sum = 0;
    for (var i = 0; i < m; i++) {
        sum += selector[i];
    }
    sum === 1;

    signal sums[n][m+1];
    // note: loop order is column-wise, not row-wise
    for (var j = 0; j < n; j++) {
        sums[j][0] <== 0;
        for (var i = 0; i < m; i++) {
            sums[j][i+1] <== sums[j][i] + in[i][j] * selector[i];
        }
        out[j] <== sums[j][m];
    }
}