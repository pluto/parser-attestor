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

interface NIVCData {
    step_out: number[];
}

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

let http_parse_and_lock_start_line = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/parse_and_lock_start_line.json"));
let http_body_mask = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/body_mask.json"));

describe("HTTPParseAndLockStartLineNIVC", async () => {
    let circuit: WitnessTester<["step_in"], ["step_out"]>;

    let DATA_BYTES = 320;
    let MAX_STACK_HEIGHT = 5;
    let PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;

    let TOTAL_BYTES_ACROSS_NIVC = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1;

    let beginning = [72, 84, 84, 80, 47, 49, 46, 49]; // HTTP/1.1
    let BEGINNING_LENGTH = 8;
    let middle = [50, 48, 48]; // 200
    let MIDDLE_LENGTH = 3;
    let final = [79, 75]; // OK
    let FINAL_LENGTH = 2;

    before(async () => {
        circuit = await circomkit.WitnessTester(`ParseAndLockStartLine`, {
            file: "http/nivc/parse_and_lock_start_line",
            template: "ParseAndLockStartLine",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, BEGINNING_LENGTH, MIDDLE_LENGTH, FINAL_LENGTH],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${desc}`, async () => {
            // console.log(JSON.stringify(await circuit.compute(input, ["step_out"])))
            await circuit.expectPass(input, expected);
        });

    }

    let extended_json_input = http_response_plaintext.concat(Array(Math.max(0, TOTAL_BYTES_ACROSS_NIVC - http_response_plaintext.length)).fill(0));

    generatePassCase({ step_in: extended_json_input, beginning: beginning, middle: middle, final: final }, { step_out: http_parse_and_lock_start_line.step_out }, "parsing HTTP");
});

describe("HTTPLockHeaderNIVC", async () => {
    let circuit: WitnessTester<["step_in", "header", "headerNameLength", "value", "headerValueLength"], ["step_out"]>;

    let DATA_BYTES = 320;
    let MAX_STACK_HEIGHT = 5;

    let MAX_HEADER_NAME_LENGTH = 20;
    let MAX_HEADER_VALUE_LENGTH = 35;

    before(async () => {
        circuit = await circomkit.WitnessTester(`LockHeader`, {
            file: "http/nivc/lock_header",
            template: "LockHeader",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, MAX_HEADER_NAME_LENGTH, MAX_HEADER_VALUE_LENGTH],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        input["header"] = input["header"].concat(Array(MAX_HEADER_NAME_LENGTH - input["header"].length).fill(0));
        input["value"] = input["value"].concat(Array(MAX_HEADER_VALUE_LENGTH - input["value"].length).fill(0));

        it(`(valid) witness: ${desc}`, async () => {
            // console.log(JSON.stringify(await circuit.compute(input, ["step_out"])))
            await circuit.expectPass(input, expected);
        });

    }

    let header_name = toByte("content-type");
    let header_value = toByte("application/json; charset=utf-8");

    generatePassCase({ step_in: http_parse_and_lock_start_line.step_out, header: header_name, headerNameLength: header_name.length, value: header_value, headerValueLength: header_value.length }, { step_out: http_parse_and_lock_start_line.step_out }, "locking HTTP header");
});

describe("HTTPBodyMaskNIVC", async () => {
    let circuit: WitnessTester<["step_in"], ["step_out"]>;

    let DATA_BYTES = 320;
    let MAX_STACK_HEIGHT = 5;

    before(async () => {
        circuit = await circomkit.WitnessTester(`BodyMask`, {
            file: "http/nivc/body_mask",
            template: "HTTPMaskBodyNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${desc}`, async () => {
            // console.log(JSON.stringify(await circuit.compute(input, ["step_out"])))
            await circuit.expectPass(input, expected);
        });

    }

    generatePassCase({ step_in: http_parse_and_lock_start_line.step_out }, { step_out: http_body_mask.step_out }, "locking HTTP header");
});