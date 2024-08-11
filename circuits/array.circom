pragma circom 2.1.9;

include "operators.circom";

template PadArray(len, paddedLen) {
    signal input in[len];
    signal output out[paddedLen];

    for (var i=0 ; i<len ; i++) {
        out[i] <== in[i];
    }

    for (var i=len ; i<paddedLen ; i++) {
        out[i] <== 0;
    }
}

/// @title ItemAtIndex
/// @notice Select item at given index from the input array
/// @notice This template that the index is valid
/// @notice This is a modified version of QuinSelector from MACI https://github.com/privacy-scaling-explorations/maci/
/// @param maxArrayLen The number of elements in the array
/// @input in The input array
/// @input index The index of the element to select
/// @output out The selected element
template ItemAtIndex(maxArrayLen) {
    signal input in[maxArrayLen];
    signal input index;

    signal output out;

    component calcTotalValue = CalculateTotal(maxArrayLen);
    component calcTotalIndex = CalculateTotal(maxArrayLen);
    component eqs[maxArrayLen];

    // For each item, check whether its index equals the input index.
    for (var i = 0; i < maxArrayLen; i ++) {
        eqs[i] = IsEqual();
        eqs[i].in[0] <== i;
        eqs[i].in[1] <== index;

        // eqs[i].out is 1 if the index matches - so calcTotal is sum of 0s + 1 * valueAtIndex
        calcTotalValue.nums[i] <== eqs[i].out * in[i];

        // Take the sum of all eqs[i].out and assert that it is at most 1.
        calcTotalIndex.nums[i] <== eqs[i].out;
    }

    // Assert that the sum of eqs[i].out is 1. This is to ensure the index passed is valid.
    calcTotalIndex.sum === 1;

    out <== calcTotalValue.sum;
}

/// @title CalculateTotal
/// @notice Calculate the sum of an array
/// @param n The number of elements in the array
/// @input nums The input array; assumes elements are small enough that their sum does not overflow the field
/// @output sum The sum of the input array
template CalculateTotal(n) {
    signal input nums[n];

    signal output sum;

    signal sums[n];
    sums[0] <== nums[0];

    for (var i=1; i < n; i++) {
        sums[i] <== sums[i - 1] + nums[i];
    }

    sum <== sums[n - 1];
}

template SubstringMatchWithChunking(tempDataLen, tempKeyLen) {
    signal input tempData[tempDataLen];
    signal input tempKey[tempKeyLen];
    signal input start;

    var keyLen = nextMultiple(tempKeyLen, 31);
    var dataLen = nextMultiple(tempDataLen, 31);

    signal data[dataLen] <== PadArray(tempDataLen, dataLen)(tempData);
    signal key[keyLen] <== PadArray(tempKeyLen, keyLen)(tempKey);

    // key end index
    var end = start + tempKeyLen;

    // `dataLen` bit length
    var logDataLen = log2Ceil(dataLen);

    // total chunks in data
    var dataChunkLength = computeIntChunkLength(dataLen);

    // initial chunk index in data
    var pos_chunk = 0;
    signal isChunkPosLess[dataChunkLength];
    signal isChunkPosGreat[dataChunkLength];
    signal isEq[dataChunkLength];
    for (var i=0 ; i<dataChunkLength ; i++) {
        var chunkStart = i*31;
        var chunkEnd = (i+1)*31;

        isChunkPosGreat[i] <== GreaterEqThan(logDataLen)([start, chunkStart]);
        isChunkPosLess[i] <== LessThan(logDataLen)([start, chunkEnd]);
        isEq[i] <== isChunkPosLess[i] * isChunkPosGreat[i];
        pos_chunk += i * isEq[i];
    }

    // final chunk index in data
    var end_chunk = 0;
    signal isEndChunkPosLess[dataChunkLength];
    signal isEndChunkPosGreat[dataChunkLength];
    signal isEndEq[dataChunkLength];
    for (var i=0 ; i<dataChunkLength ; i++) {
        var chunkStart = i*31;
        var chunkEnd = (i+1)*31;

        isEndChunkPosGreat[i] <== GreaterEqThan(logDataLen)([end, chunkStart]);
        isEndChunkPosLess[i] <== LessThan(logDataLen)([end, chunkEnd]);
        isEndEq[i] <== isEndChunkPosLess[i] * isEndChunkPosGreat[i];
        end_chunk += i * isEndEq[i];
    }

    // initial and final chunk index in data
    var initial_chunk_index = pos_chunk * 31;
    var end_chunk_index = end_chunk * 31;
    log("chunk_index", pos_chunk, start, initial_chunk_index, end_chunk_index);

    // how many bytes of key in inital chunk
    var num_key_bytes_in_first_chunk = (initial_chunk_index + 31) - start;

    // is initial and final key chunks same?
    var merge_initial_final_key_chunks = IsEqual()([pos_chunk, end_chunk]);

    // total full chunks occupied by key
    var num_full_chunks = Mux1()([(keyLen - num_key_bytes_in_first_chunk) / 31, 0], merge_initial_final_key_chunks);

    // index of key in starting byte of final chunk
    var key_index_starting_byte_of_final_chunk = Mux1()([(num_full_chunks * 31) + num_key_bytes_in_first_chunk, 0], merge_initial_final_key_chunks);

    // index of chunk containing final key byte
    var chunk_index_of_final_haystack_chunk_with_matching_needle_bytes = Mux1()([num_full_chunks + initial_chunk_index + 1, initial_chunk_index], merge_initial_final_key_chunks);

    // data chunks of 31 bytes each
    signal input_chunks[dataChunkLength];
    input_chunks <== PackBytes(dataLen)(data);
    log(input_chunks[0]);

    // total chunks in padded key
    // ideally it's ((keyLen/31) + 1) - 1
    var total_chunks_in_padded_key = keyLen \ 31;

    var num_data_bytes_in_initial_chunk = 31 - num_key_bytes_in_first_chunk;

    // calculate initial chunk
    signal initial_chunk[31];
    component less_than_start_index[31];
    for (var i=0 ; i<31 ; i++) {
        less_than_start_index[i] = LessThan(logDataLen);
        less_than_start_index[i].in <== [i + initial_chunk_index, start];
        var predicate = less_than_start_index[i].out;

        var data_item = ItemAtIndex(dataLen)(data, initial_chunk_index + i);
        // log("initial_chunk_data_item:", predicate, i, data_item);
        var key_item = ItemAtIndex(keyLen)(key, (1 - predicate) * (i - num_data_bytes_in_initial_chunk));
        // log("initial_chunk_key_item:", i, key_item, data_item);
        initial_chunk[i] <== Mux1()([key_item, data_item], predicate);
    }
    log("initial_chunk:", initial_chunk[0]);

    // calculate final chunk
    signal final_chunk[31];
    component less_than_end_index[31];
    for (var i=0 ; i<31 ; i++) {
        // predicate: if i < key_end_index
        less_than_end_index[i] = LessThan(logDataLen);
        less_than_end_index[i].in <== [i+end_chunk_index, end];
        var predicate = less_than_end_index[i].out;

        var key_item = ItemAtIndex(keyLen)(key, i+key_index_starting_byte_of_final_chunk);
        var initial_chunk_item = initial_chunk[i];
        var data_item = ItemAtIndex(dataLen)(data, end_chunk_index+i);
        //                          00          10          01          11
        final_chunk[i] <== Mux2()([data_item, data_item, key_item, initial_chunk_item], [merge_initial_final_key_chunks, predicate]);
        // log("final_chunk_predicate", i, merge_initial_final_key_chunks, predicate, final_chunk[i], initial_chunk_item, data_item);
    }
    log("final_chunk:", final_chunk[0]);

    signal initial_needle_chunk[31];
    signal final_needle_chunk[31];
    initial_needle_chunk[0] <== initial_chunk[0];
    final_needle_chunk[0] <== final_chunk[0];
    for (var i=1 ; i<31 ; i++) {
        initial_needle_chunk[i] <== initial_needle_chunk[i-1] + (256**i) * initial_chunk[i];
        final_needle_chunk[i] <== final_needle_chunk[i-1] + (256**i) * final_chunk[i];
    }

    signal initial_needle_chunk_final <== initial_needle_chunk[30];
    signal final_needle_chunk_final <== final_needle_chunk[30];

    // if initial and final key chunks are same, then substitute inital key chunk with final key chunk
    signal initial_needle_chunk_2 <== Mux1()([initial_needle_chunk_final, final_needle_chunk_final], merge_initial_final_key_chunks);
    // log("initial_needle_chunk:", initial_needle_chunk, "final_needle_chunk:", final_needle_chunk, initial_needle_chunk_2, merge_initial_final_key_chunks);

    // get inital and final data chunk
    signal initial_haystack_chunk <== ItemAtIndex(dataChunkLength)(input_chunks, pos_chunk);
    signal final_haystack_chunk <== ItemAtIndex(dataChunkLength)(input_chunks, end_chunk);

    log("initial_haystack_chunk", initial_haystack_chunk, "final_haystack_chunk", final_haystack_chunk);
    initial_needle_chunk_2 === initial_haystack_chunk;
    final_needle_chunk_final === final_haystack_chunk;

    log("num_key_bytes_in_first_chunk", num_key_bytes_in_first_chunk);
    log("total_chunks_in_padded_key", total_chunks_in_padded_key);
    var total_chunks_in_padded_key_minus_one = total_chunks_in_padded_key - 1;
    signal key_chunks[total_chunks_in_padded_key_minus_one];
    for (var i=0 ; i<total_chunks_in_padded_key_minus_one ; i++) {
        var key_chunk = 0;
        for (var j=0 ; j<31 ; j++) {
            var key_item = ItemAtIndex(keyLen)(key, num_key_bytes_in_first_chunk + (i*31) + j);
            key_chunk += (256**j) + key_item;
        }

        key_chunks[i] <== key_chunk;
    }

    component less_than_num_full_chunks[total_chunks_in_padded_key_minus_one];
    signal predicate[total_chunks_in_padded_key_minus_one];
    signal data_chunk_item[total_chunks_in_padded_key_minus_one];
    var logTotalChunks = log2Ceil(total_chunks_in_padded_key_minus_one);
    for (var i=0 ; i<total_chunks_in_padded_key_minus_one; i++) {
        less_than_num_full_chunks[i] = LessThan(logTotalChunks);
        less_than_num_full_chunks[i].in[0] <== i;
        less_than_num_full_chunks[i].in[1] <== num_full_chunks;
        predicate[i] <== less_than_num_full_chunks[i].out;
        data_chunk_item[i] <== ItemAtIndex(dataChunkLength)(input_chunks, i+pos_chunk+1);
        predicate[i] * (key_chunks[i] - data_chunk_item[i]) === 0;
    }
}
