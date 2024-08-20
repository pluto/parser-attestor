import { circomkit, WitnessTester, generateDescription } from "./common";
import { readFileSync } from "fs";
import { join } from "path";

describe("ExtractValue", () => {
    let circuit: WitnessTester<["data", "key"], ["value"]>;

    function readInputFile(filename: string, key: string, index: number | undefined): [number[], number[], number[]] {
        const value_string_path = join(__dirname, "..", "..", "json_examples", "test", filename);

        let input: number[] = [];
        let output: number[] = [];

        let data = readFileSync(value_string_path, 'utf-8');

        let keyUnicode: number[] = [];
        for (let i = 0; i < key.length; i++) {
            keyUnicode.push(key.charCodeAt(i));
        }

        const byteArray = [];
        for (let i = 0; i < data.length; i++) {
            byteArray.push(data.charCodeAt(i));
        }
        input = byteArray;

        let jsonFile = JSON.parse(data);
        let jsonValue = jsonFile[key];
        let value: any;
        if (typeof jsonValue === "number" || typeof jsonValue === "string") {
            value = jsonValue.toString();
        } else if (typeof jsonValue === "object") {
            value = jsonValue[index as number].toString();
        }
        for (let i = 0; i < value.length; i++) {
            output.push(value.charCodeAt(i));
        }

        return [input, keyUnicode, output];
    }

    it("value_string: {\"a\": \"b\"}", async () => {
        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractString",
            params: [12, 1, 1, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let [input, keyUnicode, output] = readInputFile("value_string.json", "k", undefined);

        await circuit.expectPass({
            data: input, key: keyUnicode,
        }, {
            value: output,
        });
    });

    it("two_keys: {\"key1\": \"abc\", \"key2\": \"def\" }", async () => {
        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractString",
            params: [40, 1, 4, 3],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let [input1, keyUnicode1, output1] = readInputFile("two_keys.json", "key1", undefined);
        await circuit.expectPass({ data: input1, key: keyUnicode1 }, { value: output1 });

        let [input2, keyUnicode2, output2] = readInputFile("two_keys.json", "key2", undefined);
        await circuit.expectPass({ data: input2, key: keyUnicode2 }, { value: output2 });
    });

    it("value_number: {\"k\": 69 }", async () => {
        circuit = await circomkit.WitnessTester(`Extract`, {
            file: "circuits/fetcher",
            template: "ExtractNumber",
            params: [12, 1, 1, 2],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let [input1, keyUnicode1, output1] = readInputFile("value_number.json", "k", undefined);
        console.log("output:", input1, output1);
        let num = parseInt(output1.map(num => String.fromCharCode(num)).join(''), 10);

        // await circuit.expectPass({ data: input1, key: keyUnicode1 }, { value: num });
    });

    it("value_array: { \"k\" : [   420 , 69 , 4200 , 600 ], \"b\": [ \"ab\" ,  \"ba\",  \"ccc\", \"d\" ] }", async () => {
        for (let i = 0; i < 4; i++) {
            let [input, keyUnicode, output] = readInputFile("value_array.json", "b", i);

            circuit = await circomkit.WitnessTester(`Extract`, {
                file: "circuits/fetcher",
                template: "ExtractArray",
                params: [73, 2, 1, i, output.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, key: keyUnicode }, { value: output });
        }
    });
});