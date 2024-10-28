import { circomkit, WitnessTester, toByte } from "../../common";
import { readHTTPInputFile } from "../../common/http";

// 320 bytes in the HTTP response
let http_response_plaintext = [
    72, 84, 84, 80, 47, 49, 46, 49, 32, 50, 48, 48, 32, 79, 75, 13, 10, 99, 111, 110, 116, 101, 110,
    116, 45, 116, 121, 112, 101, 58, 32, 97, 112, 112, 108, 105, 99, 97, 116, 105, 111, 110, 47, 106,
    115, 111, 110, 59, 32, 99, 104, 97, 114, 115, 101, 116, 61, 117, 116, 102, 45, 56, 13, 10, 99,
    111, 110, 116, 101, 110, 116, 45, 101, 110, 99, 111, 100, 105, 110, 103, 58, 32, 103, 122, 105,
    112, 13, 10, 84, 114, 97, 110, 115, 102, 101, 114, 45, 69, 110, 99, 111, 100, 105, 110, 103, 58,
    32, 99, 104, 117, 110, 107, 101, 100, 13, 10, 13, 10, 123, 13, 10, 32, 32, 32, 34, 100, 97, 116,
    97, 34, 58, 32, 123, 13, 10, 32, 32, 32, 32, 32, 32, 32, 34, 105, 116, 101, 109, 115, 34, 58, 32,
    91, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 123, 13, 10, 32, 32, 32, 32, 32, 32, 32,
    32, 32, 32, 32, 32, 32, 32, 32, 34, 100, 97, 116, 97, 34, 58, 32, 34, 65, 114, 116, 105, 115,
    116, 34, 44, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 34, 112, 114,
    111, 102, 105, 108, 101, 34, 58, 32, 123, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
    32, 32, 32, 32, 34, 110, 97, 109, 101, 34, 58, 32, 34, 84, 97, 121, 108, 111, 114, 32, 83, 119,
    105, 102, 116, 34, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 125, 13,
    10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 125, 13, 10, 32, 32, 32, 32, 32, 32, 32, 93, 13,
    10, 32, 32, 32, 125, 13, 10, 125];

describe("HTTPParseAndLockStartLine", async () => {
    let httpParseAndLockStartLineCircuit: WitnessTester<["step_in", "beginning", "beginning_length", "middle", "middle_length", "final", "final_length"], ["step_out"]>;

    const DATA_BYTES = 320;
    const MAX_STACK_HEIGHT = 5;
    const PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;
    const TOTAL_BYTES_ACROSS_NIVC = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1;

    const MAX_BEGINNING_LENGTH = 10;
    const MAX_MIDDLE_LENGTH = 50;
    const MAX_FINAL_LENGTH = 10;

    before(async () => {
        httpParseAndLockStartLineCircuit = await circomkit.WitnessTester(`ParseAndLockStartLine`, {
            file: "http/nivc/parse_and_lock_start_line",
            template: "ParseAndLockStartLine",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, MAX_BEGINNING_LENGTH, MAX_MIDDLE_LENGTH, MAX_FINAL_LENGTH],
        });
        console.log("#constraints:", await httpParseAndLockStartLineCircuit.getConstraintCount());
    });

    it("request", async () => {
        let { input, } = readHTTPInputFile("spotify_top_artists_request.http");
        let extendedInput = input.concat(Array(Math.max(0, TOTAL_BYTES_ACROSS_NIVC - input.length)).fill(0));

        let beginning = toByte("GET");
        let middle = toByte("/v1/me/top/artists?time_range=medium_term&limit=1");
        let final = toByte("HTTP/1.1");

        let beginningPadded = beginning.concat(Array(MAX_BEGINNING_LENGTH - beginning.length).fill(0));
        let middlePadded = middle.concat(Array(MAX_MIDDLE_LENGTH - middle.length).fill(0));
        let finalPadded = final.concat(Array(MAX_FINAL_LENGTH - final.length).fill(0));

        await httpParseAndLockStartLineCircuit.expectPass({ step_in: extendedInput, beginning: beginningPadded, beginning_length: beginning.length, middle: middlePadded, middle_length: middle.length, final: finalPadded, final_length: final.length });
    })

    it("response", async () => {
        let beginning = toByte("HTTP/1.1");
        let middle = toByte("200");
        let final = toByte("OK");

        let extendedInput = http_response_plaintext.concat(Array(Math.max(0, TOTAL_BYTES_ACROSS_NIVC - http_response_plaintext.length)).fill(0));

        let beginningPadded = beginning.concat(Array(MAX_BEGINNING_LENGTH - beginning.length).fill(0));
        let middlePadded = middle.concat(Array(MAX_MIDDLE_LENGTH - middle.length).fill(0));
        let finalPadded = final.concat(Array(MAX_FINAL_LENGTH - final.length).fill(0));

        await httpParseAndLockStartLineCircuit.expectPass({ step_in: extendedInput, beginning: beginningPadded, beginning_length: beginning.length, middle: middlePadded, middle_length: middle.length, final: finalPadded, final_length: final.length });
    });
});