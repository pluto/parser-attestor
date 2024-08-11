pragma circom  2.1.9;

include "circomlib/circuits/mux1.circom";
include "./utils/hash.circom";
include "./utils/operators.circom";

/// @title SubstringSearch
/// @notice Calculates the index of a substring within a larger string. Uses a probabilistic algorithm to
///         find a substring that is equal to random linear combination of difference between each element of `data` and `key`.
///         `position` returned as output can be a false positive.
/// @dev Is underconstrained and not suitable for standalone usage, i.e. `position` returned can be spoofed by an adversary.
///      Must be verified with a similar template like `SubstringMatch`
/// @param dataLen The maximum length of the input string
/// @param keyLen The maximum length of the substring to be matched
/// @input data Array of ASCII characters as input string
/// @input key Array of ASCII characters as substring to be searched in `data`
/// @output position Index of `key` in `data`
/// @profile 6 * `dataLen` constraints
template SubstringSearch(dataLen, keyLen, random_num) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal output position;

    assert(dataLen > 0);
    assert(keyLen > 0);
    assert(dataLen >= keyLen);

    signal pos[dataLen-keyLen+2];
    pos[0] <== 0;
    signal num_matches[dataLen-keyLen+2];
    num_matches[0] <== 0;

    // iterate through each substring of length `keyLen` in `data` and find substring that matches.
    signal is_match_found[dataLen-keyLen+1];
    signal is_first_match[dataLen-keyLen+1];
    signal index_at_first_match_and_found[dataLen-keyLen+1];
    for (var i = 0; i < dataLen - keyLen + 1; i++) {
        // this is the underconstrained part, any malicious prover can set found to `0` manually
        var found;
        for (var j=0 ; j < keyLen ; j++) {
            found += (random_num**j) * (data[i+j] - key[j]);
        }

        // is substring a match?
        is_match_found[i] <== IsZero()(found);

        // update total number of matches found
        num_matches[i+1] <== num_matches[i] + is_match_found[i];

        // is substring first match?
        is_first_match[i] <== IsEqual()([1, num_matches[i+1]]);

        // n
        // should be only first match
        index_at_first_match_and_found[i] <== Mux1()([0, i], is_match_found[i] * is_first_match[i]);
        pos[i+1] <== pos[i] + index_at_first_match_and_found[i];
    }

    assert(pos[dataLen-keyLen+1] < dataLen - keyLen + 1);
    position <== pos[dataLen-keyLen+1];
}

/// @title SubstringMatchWithIndex
/// @notice RLC algorithm for matching substring at index.
///         - Creates a mask for `data` at `[start, start + keyLen]`
///         - apply mask to data
///         - multiply data with powers of `r` to create random linear combination
///         - multiply key with powers of `r`
///         - sum of both arrays should be equal
/// @notice Modified from https://github.com/zkemail/zk-email-verify/tree/main/packages/circuits
/// @param dataLen The maximum length of the input string
/// @param keyLen The maximum length of the substring to be matched
/// @input data Array of ASCII characters as input string
/// @input key Array of ASCII characters as substring to be searched in `data`
/// @input position Index of `key` in `data`
/// @profile 9 * `dataLen` constraints
template SubstringMatchWithIndex(dataLen, keyLen) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal input r;
    signal input start;

    // key end index in `data`
    signal end;
    end <== start + keyLen;

    // 2n constraints
    //
    // create start mask from [pos, dataLen-1]
    // | 0 | 0 0 0 0 0 0 |1| 1 1 1 |1| 1 1 |1|
    //   0              start      end   dataLen
    signal startMask[dataLen];
    signal startMaskEq[dataLen];
    startMaskEq[0] <== IsEqual()([0, start]);
    startMask[0] <== startMaskEq[0];
    for (var i = 1 ; i < dataLen ; i++) {
        startMaskEq[i] <== IsEqual()([i, start]);
        startMask[i] <== startMask[i-1] + startMaskEq[i];
    }

    // 3n constraints
    //
    // create end mask from [0, end]
    // | 1 | 1 1 1 1 1 1 |1| 1 1 1 |1| 0 0 |0|
    //   0              start      end   dataLen
    signal endMask[dataLen];
    signal endMaskEq[dataLen];
    endMaskEq[0] <== IsEqual()([0, end]);
    endMask[0] <== 1 - endMaskEq[0];
    for (var i = 1 ; i < dataLen ; i++) {
        endMaskEq[i] <== IsEqual()([i, end]);
        endMask[i] <== endMask[i-1] * (1 - endMaskEq[i]);
    }

    // n constraints
    //
    // combine start mask and end mask
    // | 0 | 0 0 0 0 0 0 |1| 1 1 1 |1| 0 0 |0|
    //   0              start      end   dataLen
    signal mask[dataLen];
    for (var i = 0; i < dataLen; i++) {
        mask[i] <== startMask[i] * endMask[i];
    }

    // n constraints
    //
    // masked data from mask
    signal maskedData[dataLen];
    for (var i = 0 ; i < dataLen ; i++) {
        maskedData[i] <== data[i] * mask[i];
    }

    // n constraints
    //
    // powers of `r` for masked data
    // if (masked data == 1) rDataMasked[i] = rDataMasked[i-1] * r
    // else rDataMasked[i] = rDataMasked[i-1]
    signal rDataMasked[dataLen];
    rDataMasked[0] <== Mux1()([1, r], mask[0]);
    for (var i = 1 ; i < dataLen ; i++) {
        rDataMasked[i] <== Mux1()([rDataMasked[i-1], rDataMasked[i-1] * r], mask[i]);
    }

    // powers of `r` for key
    signal rKeyMasked[keyLen];
    rKeyMasked[0] <== r;
    for (var i = 1; i < keyLen ; i++) {
        rKeyMasked[i] <== rKeyMasked[i-1] * r;
    }

    // n constraints
    //
    // calculate linear combination with random_num for data: data[i] = data[i-1] + (r^i * data[i])
    signal hashMaskedData[dataLen];
    hashMaskedData[0] <== rDataMasked[0] * maskedData[0];
    for (var i = 1; i < dataLen ; i++) {
        hashMaskedData[i] <== hashMaskedData[i-1] + (rDataMasked[i] * maskedData[i]);
    }

    // calculate linear combination with random_num for key: key[i] = key[i-1] + (r^i * key[i])
    signal hashMaskedKey[keyLen];
    hashMaskedKey[0] <== rKeyMasked[0] * key[0];
    for (var i = 1; i < keyLen ; i++) {
        hashMaskedKey[i] <== hashMaskedKey[i-1] + (rKeyMasked[i] * key[i]);
    }

    // final sum for data and key should be equal
    hashMaskedData[dataLen - 1] === hashMaskedKey[keyLen - 1];
}

/// @title SubstringMatch
/// @notice Matches a substring with an input string and returns the position
/// @param dataLen The maximum length of the input string
/// @param keyLen The maximum length of the substring to be matched
/// @param r Random number initialised as poseidon hash of concatenation of key and data
/// @input data Array of ASCII characters as input string
/// @input key Array of ASCII characters as substring to be searched in `data`
/// @input position Index of `key` in `data`
/// @profile 9 * `dataLen` constraints
template SubstringMatch(dataLen, keyLen, r) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal output position;

    // r must be secret, so either has to be derived from hash in the circuit or off the circuit
    component rHasher = PoseidonModular(dataLen + keyLen);
    for (var i = 0; i < keyLen; i++) {
        rHasher.in[i] <== key[i];
    }
    for (var i = 0; i < dataLen; i++) {
        rHasher.in[i + keyLen] <== data[i];
    }
    r === rHasher.out;

    // find the start position of `key` first match in `data`
    // NOTE: underconstrained (should be paired with SubstringMatchWithIndex)
    signal start <== SubstringSearch(dataLen, keyLen, r)(data, key);
    log(start);

    // matches a `key` in `data` at `pos`
    // NOTE: constrained verification assures correctness
    SubstringMatchWithIndex(dataLen, keyLen)(data, key, rHasher.out, start);

    position <== start;
}