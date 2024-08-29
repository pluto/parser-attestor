import { circomkit, WitnessTester, generateDescription } from "../common";

describe("HTTP :: Interpreter", async () => {
    describe("YieldMethod", async () => {
        let circuit: WitnessTester<["bytes"], ["MethodTag"]>;

        function generatePassCase(input: any, expected: any, depth: number, desc: string) {
            const description = generateDescription(input);

            it(`(valid) witness: ${description} ${desc}`, async () => {
                circuit = await circomkit.WitnessTester(`YieldMethod`, {
                    file: "circuits/http/interpreter",
                    template: "YieldMethod",
                    params: [4],
                });
                console.log("#constraints:", await circuit.getConstraintCount());

                await circuit.expectPass(input, expected);
            });
        }

        // The string `"GET "`
        generatePassCase({ bytes: [71, 69, 84, 32] }, { MethodTag: 1 }, 0, "");
    });
});