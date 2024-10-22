import { circomkit, WitnessTester, generateDescription, readJsonFile, toByte } from "../../common";
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

// 202 bytes in the JSON
let json_input = [123, 13, 10, 32, 32, 32, 34, 100, 97, 116, 97, 34, 58, 32, 123, 13, 10, 32, 32, 32, 32, 32, 32,
    32, 34, 105, 116, 101, 109, 115, 34, 58, 32, 91, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
    32, 123, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 34, 100, 97, 116,
    97, 34, 58, 32, 34, 65, 114, 116, 105, 115, 116, 34, 44, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32,
    32, 32, 32, 32, 32, 32, 32, 34, 112, 114, 111, 102, 105, 108, 101, 34, 58, 32, 123, 13, 10, 32,
    32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 34, 110, 97, 109, 101, 34, 58, 32,
    34, 84, 97, 121, 108, 111, 114, 32, 83, 119, 105, 102, 116, 34, 13, 10, 32, 32, 32, 32, 32, 32,
    32, 32, 32, 32, 32, 32, 32, 32, 32, 125, 13, 10, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 125,
    13, 10, 32, 32, 32, 32, 32, 32, 32, 93, 13, 10, 32, 32, 32, 125, 13, 10, 125];

describe("NIVC Extract", async () => {
    let parse_circuit: WitnessTester<["step_in"], ["step_out"]>;
    let json_mask_object_circuit: WitnessTester<["step_in", "key", "keyLen"], ["step_out"]>;
    let json_mask_arr_circuit: WitnessTester<["step_in", "index"], ["step_out"]>;
    let extract_value_circuit: WitnessTester<["step_in"], ["step_out"]>;

    const DATA_BYTES = 202;
    const MAX_STACK_HEIGHT = 5;
    const MAX_KEY_LENGTH = 8;
    const MAX_VALUE_LENGTH = 35;
    const PER_ITERATION_DATA_LENGTH = MAX_STACK_HEIGHT * 2 + 2;
    const TOTAL_BYTES_ACROSS_NIVC = DATA_BYTES * (PER_ITERATION_DATA_LENGTH + 1) + 1;

    before(async () => {
        parse_circuit = await circomkit.WitnessTester(`JsonParseNIVC`, {
            file: "json/nivc/parse",
            template: "JsonParseNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT],
        });
        console.log("#constraints:", await parse_circuit.getConstraintCount());

        json_mask_arr_circuit = await circomkit.WitnessTester(`JsonMaskArrayIndexNIVC`, {
            file: "json/nivc/masker",
            template: "JsonMaskArrayIndexNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT],
        });
        console.log("#constraints:", await json_mask_arr_circuit.getConstraintCount());

        json_mask_object_circuit = await circomkit.WitnessTester(`JsonMaskObjectNIVC`, {
            file: "json/nivc/masker",
            template: "JsonMaskObjectNIVC",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, MAX_KEY_LENGTH],
        });
        console.log("#constraints:", await json_mask_object_circuit.getConstraintCount());

        extract_value_circuit = await circomkit.WitnessTester(`JsonMaskExtractFinal`, {
            file: "json/nivc/extractor",
            template: "MaskExtractFinal",
            params: [DATA_BYTES, MAX_STACK_HEIGHT, MAX_VALUE_LENGTH],
        });
        console.log("#constraints:", await extract_value_circuit.getConstraintCount());
    });

    let extended_json_input = json_input.concat(Array(Math.max(0, TOTAL_BYTES_ACROSS_NIVC - json_input.length)).fill(0));

    let key0 = [100, 97, 116, 97, 0, 0, 0, 0]; // "data"
    let key0Len = 4;
    let key1 = [105, 116, 101, 109, 115, 0, 0, 0]; // "items"
    let key1Len = 5;
    let key2 = [112, 114, 111, 102, 105, 108, 101, 0]; // "profile"
    let key2Len = 7;
    let key3 = [110, 97, 109, 101, 0, 0, 0, 0]; "name"
    let key3Len = 4;

    let value = toByte("\"Taylor Swift\"");

    it("parse and mask", async () => {
        let json_parse = await parse_circuit.compute({ step_in: extended_json_input }, ["step_out"]);

        let json_extract_key0 = await json_mask_object_circuit.compute({ step_in: json_parse.step_out, key: key0, keyLen: key0Len }, ["step_out"]);

        let json_extract_key1 = await json_mask_object_circuit.compute({ step_in: json_extract_key0.step_out, key: key1, keyLen: key1Len }, ["step_out"]);

        let json_extract_arr = await json_mask_arr_circuit.compute({ step_in: json_extract_key1.step_out, index: 0 }, ["step_out"]);

        let json_extract_key2 = await json_mask_object_circuit.compute({ step_in: json_extract_arr.step_out, key: key2, keyLen: key2Len }, ["step_out"]);

        let json_extract_key3 = await json_mask_object_circuit.compute({ step_in: json_extract_key2.step_out, key: key3, keyLen: key3Len }, ["step_out"]);

        value = value.concat(Array(MAX_VALUE_LENGTH - value.length).fill(0));
        await extract_value_circuit.expectPass({ step_in: json_extract_key3.step_out }, { step_out: value });
    });
});