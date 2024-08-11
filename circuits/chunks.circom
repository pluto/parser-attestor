// from: https://github.com/zkemail/zk-email-verify/blob/main/packages/circuits/utils/array.circom
pragma circom 2.1.9;

// Field support maximum of ~253 bit
function MAX_BYTES_IN_FIELD() {
    return 31;
}

function computeIntChunkLength(byteLength) {
    var packSize = MAX_BYTES_IN_FIELD();

    var remain = byteLength % packSize;
    var numChunks = (byteLength - remain) / packSize;
    if (remain > 0) {
        numChunks += 1;
    }

    return numChunks;
}


/// @title PackBytes
/// @notice Pack an array of bytes to numbers that fit in the field
/// @param maxBytes the maximum number of bytes in the input array
/// @input in the input byte array; assumes elements to be bytes
/// @output out the output integer array
template PackBytes(maxBytes) {
    var packSize = MAX_BYTES_IN_FIELD();
    var maxInts = computeIntChunkLength(maxBytes);

    signal input in[maxBytes];
    signal output out[maxInts];

    signal intSums[maxInts][packSize];

    for (var i = 0; i < maxInts; i++) {
        for(var j=0; j < packSize; j++) {
            var idx = packSize * i + j;

            // Copy the previous value if we are out of bounds - we take last item as final result
            if(idx >= maxBytes) {
                intSums[i][j] <== intSums[i][j-1];
            }
            // First item of each chunk is the byte itself
            else if (j == 0){
                intSums[i][j] <== in[idx];
            }
            // Every other item is 256^j * byte
            else {
                intSums[i][j] <== intSums[i][j-1] + (1 << (8*j)) * in[idx];
            }
        }
    }

    // Last item of each chunk is the final sum
    for (var i = 0; i < maxInts; i++) {
        out[i] <== intSums[i][packSize-1];
    }
}