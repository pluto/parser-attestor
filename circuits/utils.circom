pragma circom 2.1.9;

include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/mux1.circom";

/*
All tests for this file are located in: `./test/utils/utils.test.ts`
*/

template ASCII(n) {
    signal input in[n];

    component Byte[n];
    for(var i = 0; i < n; i++) {
        Byte[i] = Num2Bits(8);
        Byte[i].in <== in[i];
    }
}

/*
This function is an indicator for two equal array inputs.

# Inputs:
- `n`: the length of arrays to compare
- `in[2][n]`: two arrays of `n` numbers
- `out`: either `0` or `1`
    - `1` if `in[0]` is equal to `in[1]` as arrays (i.e., component by component)
    - `0` otherwise
*/
template IsEqualArray(n) {
    signal input in[2][n];
    signal output out;

    var accum = 0;
    component equalComponent[n];

    for(var i = 0; i < n; i++) {
        equalComponent[i] = IsEqual();
        equalComponent[i].in[0] <== in[0][i];
        equalComponent[i].in[1] <== in[1][i];
        accum += equalComponent[i].out;
    }

    component totalEqual = IsEqual();
    totalEqual.in[0] <== n;
    totalEqual.in[1] <== accum;
    out <== totalEqual.out;
}


// TODO: There should be a way to have the below assertion come from the field itself.
/*
This function is an indicator for if an array contains an element.

# Inputs:
- `n`: the size of the array to search through
- `in`: a number
- `array[n]`: the array we want to search through
- `out`: either `0` or `1`
    - `1` if `in` is found inside `array`
    - `0` otherwise
*/
template Contains(n) {
    assert(n > 0);
    /*
    If `n = p` for this large `p`, then it could be that this function
    returns the wrong value if every element in `array` was equal to `in`.
    This is EXTREMELY unlikely and iterating this high is impossible anyway.
    But it is better to check than miss something, so we bound it by `2**254` for now.
    */
    assert(n < 2**254);
    signal input in;
    signal input array[n];
    signal output out;

    var accum = 0;
    component equalComponent[n];
    for(var i = 0; i < n; i++) {
        equalComponent[i] = IsEqual();
        equalComponent[i].in[0] <== in;
        equalComponent[i].in[1] <== array[i];
        accum = accum + equalComponent[i].out;
    }

    component someEqual = IsZero();
    someEqual.in <== accum;

    // Apply `not` to this by 1-x
    out <== 1 - someEqual.out;
}

template ArrayAdd(n) {
    signal input lhs[n];
    signal input rhs[n];
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== lhs[i] + rhs[i];
    }
}

template ArrayMul(n) {
    signal input lhs[n];
    signal input rhs[n];
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== lhs[i] * rhs[i];
    }
}

template InRange(n) {
    signal input in;
    signal input range[2];
    signal output out;

    component gte = GreaterEqThan(n);
    gte.in <== [in, range[0]];

    component lte = LessEqThan(n);
    lte.in <== [in, range[1]];

    out <== gte.out * lte.out;
}

/*
This function is creates an exhaustive switch statement from `0` up to `n`.

# Inputs:
- `m`: the number of switch cases
- `n`: the output array length
- `case`: which case of the switch to select
- `branches[m]`: the values that enable taking different branches in the switch
    (e.g., if `branch[i] == 10` then if `case == 10` we set `out == `vals[i]`)
- `vals[m][n]`: the value that is emitted for a given switch case
    (e.g., `val[i]` array is emitted on `case == `branch[i]`)

# Outputs
- `match`: is set to `0` if `case` does not match on any of `branches`
- `out[n]`: the selected output value if one of `branches` is selected (will be `[0,0,...]` otherwise)
*/
template SwitchArray(m, n) {
    assert(m > 0);
    assert(n > 0);
    signal input case;
    signal input branches[m];
    signal input vals[m][n];
    signal output match;
    signal output out[n];


    // Verify that the `case` is in the possible set of branches
    component indicator[m];
    component matchChecker = Contains(m);
    signal component_out[m][n];
    var sum[n];
    for(var i = 0; i < m; i++) {
        indicator[i] = IsZero();
        indicator[i].in <== case - branches[i];
        matchChecker.array[i] <== 1 - indicator[i].out;
        for(var j = 0; j < n; j++) {
            component_out[i][j] <== indicator[i].out * vals[i][j];
            sum[j] += component_out[i][j];
        }
    }
    matchChecker.in <== 0;
    match <== matchChecker.out;

    out <== sum;
}

template Switch(n) {
    assert(n > 0);
    signal input case;
    signal input branches[n];
    signal input vals[n];
    signal output match;
    signal output out;


    // Verify that the `case` is in the possible set of branches
    component indicator[n];
    component matchChecker = Contains(n);
    signal temp_val[n];
    var sum;
    for(var i = 0; i < n; i++) {
        indicator[i] = IsZero();
        indicator[i].in <== case - branches[i];
        matchChecker.array[i] <== 1 - indicator[i].out;
        temp_val[i] <== indicator[i].out * vals[i];
        sum += temp_val[i];
    }
    matchChecker.in <== 0;
    match <== matchChecker.out;

    out <== sum;
}

template IsSubstringMatchWithIndex(dataLen, keyLen) {
    signal input data[dataLen];
    signal input key[keyLen];
    signal input r;
    signal input start;

    signal output out;

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
    // hashMaskedData[dataLen - 1] === hashMaskedKey[keyLen - 1];
    out <== IsZero()(hashMaskedData[dataLen-1]-hashMaskedKey[keyLen-1]);
}

// from: https://github.com/pluto/aes-proof/blob/main/circuits/aes-gcm/helper_functions.circom

template SumMultiple(n) {
    signal input nums[n];
    signal output sum;

    signal sums[n];
    sums[0] <== nums[0];

    for(var i=1; i<n; i++) {
        sums[i] <== sums[i-1] + nums[i];
    }

    sum <== sums[n-1];
}
template IndexSelector(total) {
    signal input in[total];
    signal input index;
    signal output out;

    //maybe add (index<total) check later when we decide number of bits

    component calcTotal = SumMultiple(total);
    component equality[total];

    for(var i=0; i<total; i++){
        equality[i] = IsEqual();
        equality[i].in[0] <== i;
        equality[i].in[1] <== index;
        calcTotal.nums[i] <== equality[i].out * in[i];
    }

    out <== calcTotal.sum;
}