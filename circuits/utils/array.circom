pragma circom 2.1.9;


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