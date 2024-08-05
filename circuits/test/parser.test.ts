import { circomkit, WitnessTester } from "./common";

describe("parser", () => {
    let circuit: WitnessTester<["case", "vals"], ["out"]>;

    describe("Switch", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`Switch`, {
                file: "circuits/parser",
                template: "Switch",
                params: [3],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("valid witness 0", async () => {
            await circuit.expectPass(
                { case: 0, vals: [69, 420, 1337] },
                { out: 69 },
            );
        });

    });

});
