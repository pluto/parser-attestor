pragma circom 2.1.9;

include "circomlib/circuits/comparators.circom";

/// Extract a fixed portion of an array
///
/// # Note
/// Unlike SelectSubArray, Slice uses compile-time known indices and doesn't pad the output.
/// Slice is more efficient for fixed ranges, while SelectSubArray offers runtime flexibility
///
/// # Parameters
/// - `n`: The length of the input array
/// - `start`: The starting index of the slice (inclusive)
/// - `end`: The ending index of the slice (exclusive)
///
/// # Inputs
/// - `in`: The input array of length n
///
/// # Output
/// - `out`: The sliced array of length (end - start)
template Slice(n, start, end) {
    assert(n >= end);
    assert(start >= 0);
    assert(end >= start);

    signal input in[n];
    signal output out[end - start];

    for (var i = start; i < end; i++) {
        out[i - start] <== in[i];
    }
}

/*
This template is an indicator for two equal array inputs.

# Params:
 - `n`: the length of arrays to compare

# Inputs:
 - `in[2][n]`: two arrays of `n` numbers

# Outputs:
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
This template is an indicator for if an array contains an element.

# Params:
 - `n`: the size of the array to search through

# Inputs:
 - `in`: a number
 - `array[n]`: the array we want to search through

# Outputs:
 - `out`: either `0` or `1`
    - `1` if `in` is found inside `array`
    - `0` otherwise
*/
template Contains(n) {
    assert(n > 0);
    /*
    If `n = p` for this large `p`, then it could be that this template
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

/*
This template adds two arrays component by component.

# Params:
 - `n`: the length of arrays to compare

# Inputs:
 - `in[2][n]`: two arrays of `n` numbers

# Outputs:
 - `out[n]`: the array sum value
*/
template ArrayAdd(n) {
    signal input lhs[n];
    signal input rhs[n];
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== lhs[i] + rhs[i];
    }
}

/*
This template multiplies two arrays component by component.

# Params:
 - `n`: the length of arrays to compare

# Inputs:
 - `in[2][n]`: two arrays of `n` numbers

# Outputs:
 - `out[n]`: the array multiplication value
*/
template ArrayMul(n) {
    signal input lhs[n];
    signal input rhs[n];
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== lhs[i] * rhs[i];
    }
}

/*
This template multiplies two arrays component by component.

# Params:
 - `m`: the length of the arrays to add
 - `n`: the number of arrays to add

# Inputs:
 - `arrays[m][n]`: `n` arrays of `m` numbers

# Outputs:
 - `out[m]`: the sum of all the arrays
*/
template GenericArrayAdd(m,n) {
    signal input arrays[n][m];
    signal output out[m];

    var accum[m];
    for(var i = 0; i < m; i++) {
        for(var j = 0; j < n; j++) {
            accum[i] += arrays[j][i];
        }
    }
    out <== accum;
}

/*
This template multiplies each component of an array by a scalar value.

# Params:
 - `n`: the length of the array

# Inputs:
 - `array[n]`: an array of `n` numbers

# Outputs:
 - `out[n]`: the scalar multiplied array
*/
template ScalarArrayMul(n) {
    signal input array[n];
    signal input scalar;
    signal output out[n];

    for(var i = 0; i < n; i++) {
        out[i] <== scalar * array[i];
    }
}