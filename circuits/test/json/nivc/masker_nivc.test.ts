import { circomkit, WitnessTester, generateDescription, readJsonFile } from "../../common";
import { join } from "path";

// HTTP/1.1 200 OK
// content-type: application/json; charset=utf-8
// content-encoding: gzip
// Transfer-Encoding: chunked
//
// {
//     "data": {
//         "items": [
//             {
//                 "data": "Artist",
//                 "profile": {
//                     "name": "Taylor Swift"
//                 }
//             }
//         ]
//     }
// }

// Notes:
// - "data"'s object appears at byte 14
// - colon after "items" appears at byte 31
// - 0th index of arr appears at byte 47
// - byte 64 is `"` for the data inside the array obj
// - byte 81 is where `Artist",` ends
// - byte 100 is where `"profile"` starts

interface NIVCData {
    step_out: number[];
}

// // 202 bytes in the JSON
let json_input = [123, 13, 10, 32, 32, 32, 34, 100, 97, 116, 97, 34, 58, 32, 123, 13, 10, 32, 32, 32, 32, 32, 32,
    32, 34, 105, 116, 101, 109, 115, 34, 58, 32, 91, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
    32, 123, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 34, 100, 97, 116,
    97, 34, 58, 32, 34, 65, 114, 116, 105, 115, 116, 34, 44, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32,
    32, 32, 32, 32, 32, 32, 32, 34, 112, 114, 111, 102, 105, 108, 101, 34, 58, 32, 123, 13, 10, 32,
    32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 34, 110, 97, 109, 101, 34, 58, 32,
    34, 84, 97, 121, 108, 111, 114, 32, 83, 119, 105, 102, 116, 34, 13, 10, 32, 32, 32, 32, 32, 32,
    32, 32, 32, 32, 32, 32, 32, 32, 32, 125, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 125,
    13, 10, 32, 32, 32, 32, 32, 32, 32, 93, 13, 10, 32, 32, 32, 125, 13, 10, 125];

let nivc_parse = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/nivc_parse.json"));
let nivc_extract_key0 = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/nivc_extract_key0.json"));
let nivc_extract_key1 = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/nivc_extract_key1.json"));
let nivc_extract_arr = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/nivc_extract_arr.json"));
let nivc_extract_key3 = readJsonFile<NIVCData>(join(__dirname, "..", "nivc/nivc_extract_key3.json"));

describe("JsonParseNIVC", async () => {
    let circuit: WitnessTester<["step_in"], ["step_out"]>;

    let DATA_BYTES = 202;
    let MAX_STACK_HEIGHT = 5;
    let PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;

    let TOTAL_BYTES_ACROSS_NIVC = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1;

    before(async () => {
        circuit = await circomkit.WitnessTester(`JsonParseNIVC`, {
            file: "json/nivc/parse",
            template: "JsonParseNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            await circuit.expectPass(input, expected);
        });

    }

    let extended_json_input = json_input.concat(Array(Math.max(0, TOTAL_BYTES_ACROSS_NIVC - json_input.length)).fill(0));

    generatePassCase({ step_in: extended_json_input }, { step_out: nivc_parse.step_out }, "parsing JSON");

});

describe("JsonMaskObjectNIVC", async () => {
    let circuit: WitnessTester<["step_in", "key", "keyLen"], ["step_out"]>;

    let DATA_BYTES = 202;
    let MAX_STACK_HEIGHT = 5;
    let MAX_KEY_LENGTH = 7;
    let step_out: bigint[] = [];

    before(async () => {
        circuit = await circomkit.WitnessTester(`JsonMaskObjectNIVC`, {
            file: "json/nivc/masker",
            template: "JsonMaskObjectNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, MAX_KEY_LENGTH],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${desc}`, async () => {
            // console.log(JSON.stringify(await circuit.compute(input, ["step_out"])))
            let wit = await circuit.calculateWitness(input);
            console.log("wit", wit.slice(0, 100));
            // step_out = wit;
            // await circuit.expectPass(input, expected);
        });
    }

    // let key0 = [100, 97, 116, 97, 0, 0, 0]; // "data"
    // let key0Len = 4;
    // generatePassCase({ step_in: nivc_parse.step_out, key: key0, keyLen: key0Len }, { step_out: nivc_extract_key0.step_out }, "masking json object at depth 0");

    let key1 = [105, 116, 101, 109, 115, 0, 0]; // "items"
    let key1Len = 5;
    generatePassCase({ step_in: nivc_extract_key0.step_out, key: key1, keyLen: key1Len }, { step_out: nivc_extract_key1.step_out }, "masking json object at depth 0");

    // Ran after doing arr masking
    // let key2 = [112, 114, 111, 102, 105, 108, 101]; // "profile"
    // let key2Len = 7;
    // generatePassCase({ step_in: nivc_extract_arr.step_out, key: key2, keyLen: key2Len }, { step_out: nivc_extract_key1.step_out }, "masking json object at depth 0");

    // let key3 = [110, 97, 109, 101, 0, 0, 0]; // "name"
    // let key3Len = 4;
    // generatePassCase({ step_in: nivc_extract_key3.step_out, key: key3, keyLen: key3Len }, {}, "masking json at depth 4");
});

describe("JsonMaskArrayIndexNIVC", async () => {
    let circuit: WitnessTester<["step_in", "index"], ["step_out"]>;

    let DATA_BYTES = 202;
    let MAX_STACK_HEIGHT = 5;

    before(async () => {
        circuit = await circomkit.WitnessTester(`JsonMaskArrayIndexNIVC`, {
            file: "json/nivc/masker",
            template: "JsonMaskArrayIndexNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    function generatePassCase(input: any, expected: any, desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            console.log(JSON.stringify(await circuit.compute(input, ["step_out"])))
            await circuit.expectPass(input, expected);
        });
    }

    let index = 0;
    generatePassCase({ step_in: nivc_extract_key1.step_out, index: index }, { step_out: nivc_extract_arr.step_out }, "masking json object at depth 0");
});