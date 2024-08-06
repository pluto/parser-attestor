import { circomkit, WitnessTester } from "./common";

describe("parser", () => {
    let circuit: WitnessTester<["case", "branches", "vals"], ["out"]>;

    describe("Switch", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`Switch`, {
                file: "circuits/parser",
                template: "Switch",
                params: [3, 2],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("(valid) witness: case = 0, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 0, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { out: [69, 0] },
            );
        });

        it("(valid) witness: case = 1, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 1, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { out: [420, 1] },
            );
        });

        it("(valid) witness: case = 2, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 2, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { out: [1337, 2] },
            );
        });

        it("(invalid) witness: case = 3, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectFail(
                { case: 3, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
            );
        });

        it("(valid) witness: case = 420, branches = [69, 420, 1337], vals = [[10,3], [20,5], [30,7]]", async () => {
            await circuit.expectPass(
                { case: 420, branches: [69, 420, 1337], vals: [[10, 3], [20, 5], [30, 7]] },
                { out: [20, 5] }
            );
        });

        it("(invalid) witness: case = 0, branches = [69, 420, 1337], vals = [[10,3], [20,5], [30,7]]", async () => {
            await circuit.expectFail(
                { case: 0, branches: [69, 420, 1337], vals: [[10, 3], [20, 5], [30, 7]] },
            );
        });

    });

});
