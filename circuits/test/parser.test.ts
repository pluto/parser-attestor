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

        it("(valid) witness: case = 0, vals = [69, 420, 1337]", async () => {
            await circuit.expectPass(
                { case: 0, vals: [69, 420, 1337] },
                { out: 69 },
            );
        });

        it("(valid) witness: case = 1, vals = [69, 420, 1337]", async () => {
            await circuit.expectPass(
                { case: 1, vals: [69, 420, 1337] },
                { out: 420 },
            );
        });

        it("(valid) witness: case = 2, vals = [69, 420, 1337]", async () => {
            await circuit.expectPass(
                { case: 2, vals: [69, 420, 1337] },
                { out: 1337 },
            );
        });

        it("(invalid) witness: case = 3, vals = [69, 420, 1337]", async () => {
            await circuit.expectFail(
                { case: 3, vals: [69, 420, 1337] },
            );
        });

    });

});
