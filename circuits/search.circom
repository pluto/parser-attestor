// RLC algorithm for matching substring modified from <https://github.com/zkemail/zk-email-verify>

pragma circom  2.1.9;

include "operators.circom";
include "mux1.circom";

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
/// @profile 2 * `dataLen` constraints
template SubstringSearch(dataLen, keyLen) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal output position;

    assert(dataLen > 0);
    assert(keyLen > 0);
    assert(dataLen >= keyLen);

    // random number for linear combination
    // TODO: correct this
    var random_num = 100;

    // powers of random number for combination with string search
    var r[keyLen];
    r[0] = random_num;
    for (var i=1 ; i<keyLen ; i++) {
        r[i] = r[i-1] * random_num;
    }

    var pos = 0;

    // iterate through each substring of length `keyLen` in `data` and find substring that matches.
    for (var i = 0; i < dataLen - keyLen + 1; i++) {
        var found = 0;
        for (var j=0 ; j < keyLen ; j++) {
            found += r[j] * (data[i+j] - key[j]);
        }

        var a = Mux1()([0, i], IsZero()(found));
        pos += a;
    }

    position <== pos;
}

/// @title SubstringMatch
/// @notice Matches a substring with an input string and returns the position
template SubstringMatch(dataLen, keyLen) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal output position;

    // TODO: correct this
    signal r <== 100;

    signal pos <== SubstringSearch(dataLen, keyLen)(data, key);
    log(pos);

    signal end;
    end <== pos + keyLen;

    // n
    signal startMask[dataLen];
    signal startMaskEq[dataLen];
    startMaskEq[0] <== IsEqual()([0, pos]);
    startMask[0] <== startMaskEq[0];
    for (var i = 1 ; i < dataLen ; i++) {
        startMaskEq[i] <== IsEqual()([i, pos]);
        startMask[i] <== startMask[i-1] + startMaskEq[i];
    }

    // n
    signal endMask[dataLen];
    signal endMaskEq[dataLen];
    endMaskEq[0] <== IsEqual()([0, end]);
    endMask[0] <== 1 - endMaskEq[0];
    for (var i = 1 ; i < dataLen ; i++) {
        endMaskEq[i] <== IsEqual()([i, end]);
        endMask[i] <== endMask[i-1] * (1 - endMaskEq[i]);
    }

    // n
    signal mask[dataLen];
    for (var i = 0; i < dataLen; i++) {
        mask[i] <== startMask[i] * endMask[i];
    }

    // n
    signal maskedData[dataLen];
    for (var i = 0 ; i < dataLen ; i++) {
        maskedData[i] <== data[i] * mask[i];
    }

    // n
    signal rDataMasked[dataLen];
    rDataMasked[0] <== Mux1()([1, r], mask[0]);
    for (var i = 1 ; i < dataLen ; i++) {
        rDataMasked[i] <== Mux1()([rDataMasked[i-1], rDataMasked[i-1] * r], mask[i]);
    }

    signal rKeyMasked[keyLen];
    rKeyMasked[0] <== r;
    for (var i = 1; i < keyLen ; i++) {
        rKeyMasked[i] <== rKeyMasked[i-1] * r;
    }

    // n
    signal hashMaskedData[dataLen];
    hashMaskedData[0] <== rDataMasked[0] * maskedData[0];
    for (var i = 1; i < dataLen ; i++) {
        hashMaskedData[i] <== hashMaskedData[i-1] + (rDataMasked[i] * maskedData[i]);
    }

    signal hashMaskedKey[keyLen];
    hashMaskedKey[0] <== rKeyMasked[0] * key[0];
    for (var i = 1; i < keyLen ; i++) {
        hashMaskedKey[i] <== hashMaskedKey[i-1] + (rKeyMasked[i] * key[i]);
    }

    hashMaskedData[dataLen - 1] === hashMaskedKey[keyLen - 1];

    position <== pos;
}