import { circomkit, WitnessTester, generateDescription } from "./common";
import { readFileSync } from "fs";
import { join } from "path";

function readInputFile(filename: string, key: string[], index: number | undefined): [number[], number[][], number[]] {
    const value_string_path = join(__dirname, "..", "..", "json_examples", "test", filename);

    let input: number[] = [];
    let output: number[] = [];

    let data = readFileSync(value_string_path, 'utf-8');

    let keyUnicode: number[][] = [];
    for (let i = 0; i < key.length; i++) {
        keyUnicode[i] = [];
        for (let j = 0; j < key[i].length; j++) {

            keyUnicode[i].push(key[i].charCodeAt(j));
        }
    }

    const byteArray = [];
    for (let i = 0; i < data.length; i++) {
        byteArray.push(data.charCodeAt(i));
    }
    input = byteArray;

    let jsonFile = JSON.parse(data);
    let jsonValue: string = key.reduce((acc, key) => acc && acc[key], jsonFile);
    let value: string = "";
    if (typeof jsonValue === "number" || typeof jsonValue === "string") {
        value = jsonValue.toString();
    } else if (typeof jsonValue === "object") {
        value = jsonValue[index as number];
    }
    for (let i = 0; i < value.length; i++) {
        output.push(value.charCodeAt(i));
    }

    return [input, keyUnicode, output];
}

describe("ExtractValue", () => {
    let circuit: WitnessTester<["data", "key"], ["value"]>;

    it("value_string: {\"a\": \"b\"}", async () => {
        let [input, keyUnicode, output] = readInputFile("value_string.json", ["k"], undefined);
        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractString",
            params: [input.length, 1, 1, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({
            data: input, key: keyUnicode,
        }, {
            value: output,
        });
    });

    it("two_keys: {\"key1\": \"abc\", \"key2\": \"def\" }", async () => {
        let [input1, keyUnicode1, output1] = readInputFile("two_keys.json", ["key1"], undefined);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractString",
            params: [input1.length, 1, 4, 3],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({ data: input1, key: keyUnicode1 }, { value: output1 });

        let [input2, keyUnicode2, output2] = readInputFile("two_keys.json", ["key2"], undefined);
        await circuit.expectPass({ data: input2, key: keyUnicode2 }, { value: output2 });
    });

    it("value_number: {\"k\": 69 }", async () => {
        let [input1, keyUnicode1, output1] = readInputFile("value_number.json", ["k"], undefined);
        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractNumber",
            params: [input1.length, 1, 1, 2],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let num = parseInt(output1.map(num => String.fromCharCode(num)).join(''), 10);

        await circuit.expectPass({ data: input1, key: keyUnicode1 }, { value: num });
    });

    it("value_array: { \"k\" : [   420 , 69 , 4200 , 600 ], \"b\": [ \"ab\" ,  \"ba\",  \"ccc\", \"d\" ] }", async () => {
        for (let i = 0; i < 4; i++) {
            let [input, keyUnicode, output] = readInputFile("value_array.json", ["b"], i);

            circuit = await circomkit.WitnessTester(`Extract`, {
                file: "circuits/fetcher",
                template: "ExtractArray",
                params: [input.length, 2, 1, i, output.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, key: keyUnicode }, { value: output });
        }
    });
});

describe("ExtractValueMultiDepth", () => {
    let circuit: WitnessTester<["data", "key1", "key2"], ["value"]>;

    it("value_object: { \"a\": { \"d\" : \"e\", \"e\": \"c\" }, \"e\": { \"f\": \"a\", \"e\": \"2\" } }", async () => {
        let [input, keyUnicode, output] = readInputFile("value_object.json", ["e", "e"], undefined);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractStringMultiDepth",
            params: [input.length, 3, 1, 1, 1, 2, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({ data: input, key1: keyUnicode[0], key2: keyUnicode[1] }, { value: output });

        let [input1, keyUnicode1, output1] = readInputFile("value_object.json", ["e", "f"], undefined);
        await circuit.expectPass({ data: input1, key1: keyUnicode1[0], key2: keyUnicode1[1] }, { value: output1 });
    });
});