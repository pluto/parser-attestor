pragma circom 2.1.9;

include "circomlib/circuits/poseidon.circom";
include "./array.circom";

/// Circuit to calculate Poseidon hash of an arbitrary number of inputs.
/// Splits input into chunks of 16 elements (or less for the last chunk) and hashes them separately
/// Then combines the chunk hashes using a binary tree structure.
///
/// NOTE: from <https://github.com/zkemail/zk-email-verify/blob/main/packages/circuits/utils/hash.circom#L49>
///
/// # Parameters
/// - `numElements`: Number of elements in the input array
///
/// # Inputs
/// - `in`: Array of numElements to be hashed
///
/// # Output
/// - `out`: Poseidon hash of the input array
template PoseidonModular(numElements) {
    signal input in[numElements];
    signal output out;

    var chunks = numElements \ 16;
    var last_chunk_size = numElements % 16;
    if (last_chunk_size != 0) {
        chunks += 1;
    }

    var _out;

    for (var i = 0; i < chunks; i++) {
        var start = i * 16;
        var end = start + 16;
        var chunk_hash;

        if (end > numElements) { // last chunk
            end = numElements;
            var last_chunk[last_chunk_size] = Slice(numElements, start, end)(in);
            chunk_hash = Poseidon(last_chunk_size)(last_chunk);
        } else {
            var chunk[16] = Slice(numElements, start, end)(in);
            chunk_hash = Poseidon(16)(chunk);
        }

        if (i == 0) {
            _out = chunk_hash;
        } else {
            _out = Poseidon(2)([_out, chunk_hash]);
        }
    }

    out <== _out;
}