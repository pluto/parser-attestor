import { circomkit, WitnessTester, generateDescription, toByte, readHTTPInputFile } from "../common";

describe("HTTP :: Interpreter", async () => {
    describe("MethodMatch", async () => {
        let circuit: WitnessTester<["data", "method", "r", "index"], []>;

        function generatePassCase(input: number[], method: number[], index: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`LockRequestLineData`, {
                    file: "circuits/http/interpreter",
                    template: "MethodMatch",
                    params: [input.length, method.length],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass({ data: input, method: method, r: 100, index: index }, {});
            });
        }

        function generateFailCase(input: number[], method: number[], index: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`LockRequestLineData`, {
                    file: "circuits/http/interpreter",
                    template: "MethodMatch",
                    params: [input.length, method.length],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectFail({ data: input, method: method, r: 100, index: index });
            });
        }

        let parsedHttp = readHTTPInputFile("get_request.http");
        generatePassCase(parsedHttp.input, toByte("GET"), 0, "");
        generateFailCase(parsedHttp.input, toByte("POST"), 0, "");
    });
});