import { circomkit, WitnessTester, generateDescription, readJsonFile, toByte } from "../../common";
import { join } from "path";

// HTTP/1.1 200 OK
// content-type: application/json; charset=utf-8
// content-encoding: gzip
// Transfer-Encoding: chunked
//
// {
//    "data": {
//        "items": [
//            {
//                "data": "Artist",
//                "profile": {
//                    "name": "Taylor Swift"
//                }
//            }
//        ]
//    }
// }

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

describe("HTTPParseAndLockStartLineNIVC", async () => {
    let httpParseAndLockStartLineCircuit: WitnessTester<["step_in", "beginning", "middle", "final"], ["step_out"]>;
    let lockHeaderCircuit: WitnessTester<["step_in", "header", "headerNameLength", "value", "headerValueLength"], ["step_out"]>;
    let bodyMaskCircuit: WitnessTester<["step_in"], ["step_out"]>;

    const DATA_BYTES = 320;
    const MAX_STACK_HEIGHT = 5;
    const PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;
    const TOTAL_BYTES_ACROSS_NIVC = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1;

    const MAX_HEADER_NAME_LENGTH = 20;
    const MAX_HEADER_VALUE_LENGTH = 35;

    const beginning = [72, 84, 84, 80, 47, 49, 46, 49]; // HTTP/1.1
    const BEGINNING_LENGTH = 8;
    const middle = [50, 48, 48]; // 200
    const MIDDLE_LENGTH = 3;
    const final = [79, 75]; // OK
    const FINAL_LENGTH = 2;

    before(async () => {
        httpParseAndLockStartLineCircuit = await circomkit.WitnessTester(`ParseAndLockStartLine`, {
            file: "http/nivc/parse_and_lock_start_line",
            template: "ParseAndLockStartLine",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, BEGINNING_LENGTH, MIDDLE_LENGTH, FINAL_LENGTH],
        });
        console.log("#constraints:", await httpParseAndLockStartLineCircuit.getConstraintCount());

        lockHeaderCircuit = await circomkit.WitnessTester(`LockHeader`, {
            file: "http/nivc/lock_header",
            template: "LockHeader",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, MAX_HEADER_NAME_LENGTH, MAX_HEADER_VALUE_LENGTH],
        });
        console.log("#constraints:", await lockHeaderCircuit.getConstraintCount());

        bodyMaskCircuit = await circomkit.WitnessTester(`BodyMask`, {
            file: "http/nivc/body_mask",
            template: "HTTPMaskBodyNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT],
        });
        console.log("#constraints:", await bodyMaskCircuit.getConstraintCount());
    });

    let extendedJsonInput = http_response_plaintext.concat(Array(Math.max(0, TOTAL_BYTES_ACROSS_NIVC - http_response_plaintext.length)).fill(0));

    let headerName = toByte("content-type");
    let headerValue = toByte("application/json; charset=utf-8");

    let headerNamePadded = headerName.concat(Array(MAX_HEADER_NAME_LENGTH - headerName.length).fill(0));
    let headerValuePadded = headerValue.concat(Array(MAX_HEADER_VALUE_LENGTH - headerValue.length).fill(0));
    it("HTTPParseAndExtract", async () => {
        let parseAndLockStartLine = await httpParseAndLockStartLineCircuit.compute({ step_in: extendedJsonInput, beginning: beginning, middle: middle, final: final }, ["step_out"]);

        let lockHeader = await lockHeaderCircuit.compute({ step_in: parseAndLockStartLine.step_out, header: headerNamePadded, headerNameLength: headerName.length, value: headerValuePadded, headerValueLength: headerValue.length }, ["step_out"]);

        let bodyMask = await bodyMaskCircuit.compute({ step_in: lockHeader.step_out }, ["step_out"]);

        let bodyMaskOut = bodyMask.step_out as number[];
        let idx = bodyMaskOut.indexOf('{'.charCodeAt(0));

        let extended_json_input_2 = extendedJsonInput.fill(0, 0, idx);
        extended_json_input_2 = extended_json_input_2.fill(0, 320);

        bodyMaskOut === extended_json_input_2;
    });
});