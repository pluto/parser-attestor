import { circomkit, WitnessTester, generateDescription, toByte } from "../common";
import { readHTTPInputFile } from "../common/http";

describe("HTTP :: Interpreter", async () => {
    describe("MethodMatch", async () => {
        let circuit: WitnessTester<["data", "method", "index"], []>;

        function generatePassCase(input: number[], method: number[], index: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`LockRequestLineData`, {
                    file: "http/interpreter",
                    template: "MethodMatch",
                    params: [input.length, method.length],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass({ data: input, method: method, index: index }, {});
            });
        }

        function generateFailCase(input: number[], method: number[], index: number, desc: string) {
            const description = generateDescription(input);

            it(`(invalid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`LockRequestLineData`, {
                    file: "http/interpreter",
                    template: "MethodMatch",
                    params: [input.length, method.length],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectFail({ data: input, method: method, index: index });
            });
        }

        let parsedHttp = readHTTPInputFile("get_request.http");
        generatePassCase(parsedHttp.input, toByte("GET"), 0, "");
        generateFailCase(parsedHttp.input, toByte("POST"), 0, "");
    });
});