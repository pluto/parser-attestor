import { circomkit, WitnessTester } from "./common";
import { readFileSync } from "fs";
import { join } from "path";
import { spawn } from "child_process";

export function readInputFile(filename: string, key: any[]): [number[], number[][], number[]] {
    const value_string_path = join(__dirname, "..", "..", "json_examples", "test", filename);

    let input: number[] = [];
    let output: number[] = [];

    let data = readFileSync(value_string_path, 'utf-8');

    let keyUnicode: number[][] = [];
    for (let i = 0; i < key.length; i++) {
        keyUnicode[i] = [];
        let key_string = key[i].toString();
        for (let j = 0; j < key_string.length; j++) {
            keyUnicode[i].push(key_string.charCodeAt(j));
        }
    }

    const byteArray = [];
    for (let i = 0; i < data.length; i++) {
        byteArray.push(data.charCodeAt(i));
    }
    input = byteArray;

    let jsonFile = JSON.parse(data);
    let value: string = key.reduce((acc, key) => acc && acc[key], jsonFile).toString();
    for (let i = 0; i < value.length; i++) {
        output.push(value.charCodeAt(i));
    }

    return [input, keyUnicode, output];
}

function executeCodegen(input_file_name: string, output_filename: string) {
    return new Promise((resolve, reject) => {
        const input_path = join(__dirname, "..", "..", "json_examples", "codegen", input_file_name);

        const codegen = spawn("cargo", ["run", "--bin", "codegen", "--", "--json-file", input_path, "--output-filename", output_filename]);

        codegen.stdout.on('data', (data) => {
            console.log(`stdout: ${data}`);
        });

        codegen.stderr.on('data', (data) => {
            console.error(`stderr: ${data}`);
        });

        codegen.on('close', (code) => {
            if (code === 0) {
                resolve(`child process exited with code ${code}`); // Resolve the promise if the process exits successfully
            } else {
                reject(new Error(`Process exited with code ${code}`)); // Reject if there's an error
            }
        });
    });
}

describe("ExtractValue", async () => {
    let circuit: WitnessTester<["data", "key1"], ["value"]>;

    it("value_string: {\"a\": \"b\"}", async () => {
        let filename = "value_string";
        await executeCodegen(`${filename}.json`, filename);
        let [input, keyUnicode, output] = readInputFile(`${filename}.json`, ["k"]);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${filename}`,
            template: "ExtractStringValue",
            params: [input.length, 1, 1, 0, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({
            data: input, key1: keyUnicode,
        }, {
            value: output,
        });
    });

    it("two_keys: {\"key1\": \"abc\", \"key2\": \"def\" }", async () => {
        let filename = "two_keys"
        await executeCodegen(`${filename}.json`, filename);
        let [input, keyUnicode, output] = readInputFile(`${filename}.json`, ["key2"]);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${filename}`,
            template: "ExtractStringValue",
            params: [input.length, 1, 4, 0, 3],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({ data: input, key1: keyUnicode }, { value: output });
    });

    it("value_number: {\"k\": 69 }", async () => {
        let filename = "value_number";
        await executeCodegen(`${filename}.json`, filename);
        let [input, keyUnicode, output] = readInputFile(`${filename}.json`, ["k"]);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${filename}`,
            template: "ExtractNumValue",
            params: [input.length, 1, 1, 0, 2],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let num = parseInt(output.map(num => String.fromCharCode(num)).join(''), 10);

        await circuit.expectPass({ data: input, key1: keyUnicode }, { value: num });
    });

    it("value_array_string: { \"k\" : [   420 , 69 , 4200 , 600 ], \"b\": [ \"ab\" ,  \"ba\",  \"ccc\", \"d\" ] }", async () => {
        let filename = "value_array_string";
        await executeCodegen(`${filename}.json`, filename);

        for (let i = 0; i < 4; i++) {
            let [input, keyUnicode, output] = readInputFile("value_array.json", ["b", i]);

            circuit = await circomkit.WitnessTester(`Extract`, {
                file: `circuits/main/${filename}`,
                template: "ExtractStringValue",
                params: [input.length, 2, 1, 0, i, 1, output.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, key1: keyUnicode[0] }, { value: output });
        }
    });

    it("value_array_number: { \"k\" : [   420 , 69 , 4200 , 600 ], \"b\": [ \"ab\" ,  \"ba\",  \"ccc\", \"d\" ] }", async () => {
        let filename = "value_array_number";
        await executeCodegen(`${filename}.json`, filename);

        for (let i = 0; i < 4; i++) {
            let [input, keyUnicode, output] = readInputFile("value_array.json", ["k", i]);

            circuit = await circomkit.WitnessTester(`Extract`, {
                file: `circuits/main/${filename}`,
                template: "ExtractNumValue",
                params: [input.length, 2, 1, 0, i, 1, output.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            let num = parseInt(output.map(num => String.fromCharCode(num)).join(''), 10);
            await circuit.expectPass({ data: input, key1: keyUnicode[0] }, { value: num });
        }
    });

    it("value_array_nested: { \"a\": [[1,0],[0,1,3]] }", async () => {
        let filename = "value_array_nested";
        await executeCodegen(`${filename}.json`, filename);
        let index_0 = 1;
        let index_1 = 0;
        let [input, keyUnicode, output] = readInputFile(`${filename}.json`, ["a", index_0, index_1]);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${filename}`,
            template: "ExtractNumValue",
            params: [input.length, 3, 1, 0, index_0, 1, index_1, 2, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let num = parseInt(output.map(num => String.fromCharCode(num)).join(''), 10);

        // console.log("input", input, "key:", keyUnicode, "output:", output);
        await circuit.expectPass({ data: input, key1: keyUnicode[0] }, { value: num });
    });
});

describe("ExtractValueMultiDepth", () => {
    let circuit: WitnessTester<["data", "key1", "key2"], ["value"]>;

    it("value_object: { \"a\": { \"d\" : \"e\", \"e\": \"c\" }, \"e\": { \"f\": \"a\", \"e\": \"2\" } }", async () => {
        let filename = "value_object";

        await executeCodegen(`${filename}.json`, filename);

        let [input, keyUnicode, output] = readInputFile(`${filename}.json`, ["e", "e"]);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${filename}`,
            template: "ExtractStringValue",
            params: [input.length, 3, 1, 0, 1, 1, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectPass({ data: input, key1: keyUnicode[0], key2: keyUnicode[1] }, { value: output });

        let [input1, keyUnicode1, output1] = readInputFile("value_object.json", ["e", "f"]);
        await circuit.expectPass({ data: input1, key1: keyUnicode1[0], key2: keyUnicode1[1] }, { value: output1 });
    });


});

describe("ExtractValueArrayObject", () => {
    let circuit: WitnessTester<["data", "key1", "key3"], ["value"]>;

    it("value_array_object: {\"a\":[{\"b\":[1,4]},{\"c\":\"b\"}]}", async () => {
        let filename = "value_array_object";

        await executeCodegen(`${filename}.json`, filename);

        let index_0 = 0;
        let index_1 = 0;
        let [input, keyUnicode, output] = readInputFile(`${filename}.json`, ["a", index_0, "b", index_1]);

        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${filename}`,
            template: "ExtractNumValue",
            params: [input.length, 4, 1, 0, index_0, 1, 1, 2, index_1, 3, 1],
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        let num = parseInt(output.map(num => String.fromCharCode(num)).join(''), 10);

        await circuit.expectPass({ data: input, key1: keyUnicode[0], key3: keyUnicode[2] }, { value: num });
    });
});