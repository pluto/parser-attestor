import { circomkit, WitnessTester, generateDescription } from "../common";
import { PoseidonModular } from "../common/poseidon";
import { readInputFile } from "./extractor.test";

describe("Interpreter", async () => {
    describe("InsideKey", async () => {
        let circuit: WitnessTester<["stack", "parsing_string", "parsing_number"], ["out"]>;

        before(async () => {
            circuit = await circomkit.WitnessTester(`InsideKey`, {
                file: "circuits/interpreter",
                template: "InsideKey",
                params: [4],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        function generatePassCase(input: any, expected: any, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], parsing_string: 1, parsing_number: 0 };
        let output = { out: 1 };
        generatePassCase(input1, output, "");

        let input2 = { stack: [[1, 0], [2, 0], [1, 0], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input2, output, "");

        let input3 = { stack: [[1, 0], [0, 0], [0, 0], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input3, output, "");

        // fail cases

        let input4 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input4, { out: 0 }, "invalid stack");

        let input5 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], parsing_string: 1, parsing_number: 1 };
        generatePassCase(input5, { out: 0 }, "parsing number as a key");
    });

    describe("InsideValue", async () => {
        let circuit: WitnessTester<["stack", "parsing_string", "parsing_number"], ["out"]>;

        before(async () => {
            circuit = await circomkit.WitnessTester(`InsideValue`, {
                file: "circuits/interpreter",
                template: "InsideValue",
                params: [4],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        function generatePassCase(input: any, expected: any, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 0 };
        let output = { out: 1 };
        generatePassCase(input1, output, "");

        let input2 = { stack: [[1, 0], [2, 0], [1, 1], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input2, output, "");

        let input3 = { stack: [[1, 1], [0, 0], [0, 0], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input3, output, "");

        // fail cases

        let input4 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input4, { out: 0 }, "invalid stack");

        let input5 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 1 };
        generatePassCase(input5, { out: 0 }, "parsing number and key both");
    });

    describe("InsideValueAtDepth", async () => {
        let circuit: WitnessTester<["stack", "parsing_string", "parsing_number"], ["out"]>;

        function generatePassCase(input: any, expected: any, depth: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`InsideValueAtDepth`, {
                    file: "circuits/interpreter",
                    template: "InsideValueAtDepth",
                    params: [4, depth],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 0 };
        let output = { out: 1 };
        generatePassCase(input1, output, 3, "");

        let input2 = { stack: [[1, 0], [2, 0], [1, 1], [1, 1]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input2, output, 2, "");

        let input3 = { stack: [[1, 1], [0, 0], [0, 0], [1, 1]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input3, output, 0, "");

        // fail cases

        let input4 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input4, { out: 0 }, 0, "invalid stack");

        let input5 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 1 };
        generatePassCase(input5, { out: 0 }, 3, "parsing number and key both");
    });

    describe("InsideArrayIndex", async () => {
        let circuit: WitnessTester<["stack", "parsing_string", "parsing_number"], ["out"]>;

        function generatePassCase(input: any, expected: any, index: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`InsideArrayIndex`, {
                    file: "circuits/interpreter",
                    template: "InsideArrayIndex",
                    params: [4, index],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [2, 1]], parsing_string: 1, parsing_number: 0 };
        let output = { out: 1 };
        generatePassCase(input1, output, 1, "");

        let input2 = { stack: [[1, 0], [2, 0], [2, 3], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input2, output, 3, "");

        let input3 = { stack: [[2, 10], [0, 0], [0, 0], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input3, output, 10, "");

        // fail cases

        let input4 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input4, { out: 0 }, 4, "invalid stack");

        let input5 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 1 };
        generatePassCase(input5, { out: 0 }, 4, "parsing number and key both");

        let input6 = { stack: [[1, 0], [2, 0], [3, 1], [2, 4]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input6, { out: 0 }, 3, "incorrect index");
    });

    describe("InsideArrayIndexAtDepth", async () => {
        let circuit: WitnessTester<["stack", "parsing_string", "parsing_number"], ["out"]>;

        function generatePassCase(input: any, expected: any, index: number, depth: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`InsideArrayIndexAtDepth`, {
                    file: "circuits/interpreter",
                    template: "InsideArrayIndexAtDepth",
                    params: [4, index, depth],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [2, 1]], parsing_string: 1, parsing_number: 0 };
        let output = { out: 1 };
        generatePassCase(input1, output, 1, 3, "");

        let input2 = { stack: [[1, 0], [2, 0], [2, 3], [2, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input2, output, 3, 2, "");

        let input3 = { stack: [[2, 10], [0, 0], [1, 0], [0, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input3, output, 10, 0, "");

        // fail cases

        let input4 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], parsing_string: 1, parsing_number: 0 };
        generatePassCase(input4, { out: 0 }, 4, 2, "invalid stack depth");

        let input5 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], parsing_string: 1, parsing_number: 1 };
        generatePassCase(input5, { out: 0 }, 4, 1, "parsing number and key both");
    });

    describe("NextKVPair", async () => {
        let circuit: WitnessTester<["stack", "currByte"], ["out"]>;

        before(async () => {
            circuit = await circomkit.WitnessTester(`NextKVPair`, {
                file: "circuits/interpreter",
                template: "NextKVPair",
                params: [4],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        function generatePassCase(input: any, expected: any, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], currByte: 44 };
        let output = { out: 1 };
        generatePassCase(input1, output, "");

        let input2 = { stack: [[1, 0], [2, 0], [1, 0], [0, 0]], currByte: 44 };
        generatePassCase(input2, output, "");

        let input3 = { stack: [[1, 0], [0, 0], [0, 0], [0, 0]], currByte: 44 };
        generatePassCase(input3, output, "");

        let input4 = { stack: [[1, 0], [2, 0], [3, 1], [1, 1]], currByte: 44 };
        generatePassCase(input4, { out: 0 }, "invalid stack");

        let input5 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], currByte: 34 };
        generatePassCase(input5, { out: 0 }, "incorrect currByte");
    });

    describe("NextKVPairAtDepth", async () => {
        let circuit: WitnessTester<["stack", "currByte"], ["out"]>;

        function generatePassCase(input: any, expected: any, depth: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`NextKVPairAtDepth`, {
                    file: "circuits/interpreter",
                    template: "NextKVPairAtDepth",
                    params: [4, depth],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        let input1 = { stack: [[1, 0], [2, 0], [3, 1], [1, 0]], currByte: 44 };
        // output = 0 represents correct execution
        let output = { out: 0 };
        generatePassCase(input1, output, 3, "");

        // key depth is 2, and even if new-kv pair starts at depth greater than 2, it returns 0.
        let input2 = { stack: [[1, 0], [2, 0], [1, 1], [1, 0]], currByte: 44 };
        generatePassCase(input2, output, 2, "");

        let input3 = { stack: [[1, 0], [1, 0], [0, 0], [0, 0]], currByte: 44 };
        generatePassCase(input3, { out: 1 }, 3, "stack height less than specified");

        let input4 = { stack: [[1, 0], [2, 0], [1, 0], [0, 0]], currByte: 34 };
        generatePassCase(input4, output, 2, "incorrect currByte");
    });

    describe("KeyMatch", async () => {
        let circuit: WitnessTester<["data", "key", "r", "index", "parsing_key"], ["out"]>;

        function generatePassCase(input: any, expected: any, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`KeyMatch`, {
                    file: "circuits/interpreter",
                    template: "KeyMatch",
                    params: [input.data.length, input.key.length],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        let input = readInputFile("value_array_object.json", ["a"]);
        const concatenatedInput = input[1][0].concat(input[0]);
        const hashResult = PoseidonModular(concatenatedInput);

        let output = { out: 1 };
        let input1 = { data: input[0], key: input[1][0], r: hashResult, index: 2, parsing_key: 1 };
        generatePassCase(input1, output, "");

        let input2 = { data: input[0], key: [99], r: hashResult, index: 20, parsing_key: 1 };
        generatePassCase(input2, output, "");

        // fail cases

        let input3 = { data: input[0], key: input[1][0], r: hashResult, index: 3, parsing_key: 1 };
        generatePassCase(input3, { out: 0 }, "wrong index");

        let input4 = { data: input[0], key: [98], r: hashResult, index: 2, parsing_key: 1 };
        generatePassCase(input4, { out: 0 }, "wrong key");

        let input5 = { data: input[0], key: [97], r: hashResult, index: 2, parsing_key: 0 };
        generatePassCase(input5, { out: 0 }, "not parsing key");
    });

    describe("KeyMatchAtDepth", async () => {
        let circuit: WitnessTester<["data", "key", "r", "index", "parsing_key", "stack"], ["out"]>;

        function generatePassCase(input: any, expected: any, depth: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`KeyMatchAtDepth`, {
                    file: "circuits/interpreter",
                    template: "KeyMatchAtDepth",
                    params: [input.data.length, 4, input.key.length, depth],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        let input = readInputFile("value_array_object.json", ["a", 0, "b", 0]);
        const concatenatedInput = input[1][0].concat(input[0]);
        const hashResult = PoseidonModular(concatenatedInput);

        let output = { out: 1 };

        let input1 = { data: input[0], key: input[1][0], r: hashResult, index: 2, parsing_key: 1, stack: [[1, 0], [0, 0], [0, 0], [0, 0]] };
        generatePassCase(input1, output, 0, "");

        let input2 = { data: input[0], key: input[1][2], r: hashResult, index: 8, parsing_key: 1, stack: [[1, 1], [2, 0], [1, 0], [0, 0]] };
        generatePassCase(input2, output, 2, "");

        let input3 = { data: input[0], key: [99], r: hashResult, index: 20, parsing_key: 1, stack: [[1, 1], [2, 1], [1, 1], [0, 0]] };
        generatePassCase(input3, { out: 1 }, 2, "wrong stack");

        // fail cases

        let input4 = { data: input[0], key: input[1][1], r: hashResult, index: 3, parsing_key: 1, stack: [[1, 0], [2, 0], [1, 0], [0, 0]] };
        generatePassCase(input4, { out: 0 }, 2, "wrong key");

        let input5 = { data: input[0], key: [97], r: hashResult, index: 12, parsing_key: 0, stack: [[1, 1], [2, 0], [1, 1], [0, 0]] };
        generatePassCase(input5, { out: 0 }, 3, "not parsing key");

        let input6Data = input[0].slice(0);
        let input6 = { data: input6Data.splice(1, 1, 35), key: input[1][0], r: hashResult, index: 2, parsing_key: 1, stack: [[1, 0], [0, 0], [0, 0], [0, 0]] };
        generatePassCase(input6, { out: 0 }, 0, "invalid key (not surrounded by quotes)");

        let input7 = { data: input[0], key: input[1][0], r: hashResult, index: 2, parsing_key: 1, stack: [[1, 0], [0, 0], [0, 0], [0, 0]] };
        generatePassCase(input6, { out: 0 }, 1, "wrong depth");
    });
});