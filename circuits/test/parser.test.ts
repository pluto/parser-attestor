import { circomkit, WitnessTester } from "./common";

describe("parser", () => {
    let circuit: WitnessTester<["case", "branches", "vals"], ["match", "out"]>;

    describe("Switch", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`Switch`, {
                file: "circuits/parser",
                template: "Switch",
                params: [3, 2],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: case = 0, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 0, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 1, out: [69, 0] },
            );
        });

        it("witness: case = 1, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 1, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 1, out: [420, 1] },
            );
        });

        it("witness: case = 2, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 2, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 1, out: [1337, 2] },
            );
        });

        it("witness: case = 3, branches = [0, 1, 2], vals = [[69,0], [420,1], [1337,2]]", async () => {
            await circuit.expectPass(
                { case: 3, branches: [0, 1, 2], vals: [[69, 0], [420, 1], [1337, 2]] },
                { match: 0, out: [0, 0] }
            );
        });

        it("witness: case = 420, branches = [69, 420, 1337], vals = [[10,3], [20,5], [30,7]]", async () => {
            await circuit.expectPass(
                { case: 420, branches: [69, 420, 1337], vals: [[10, 3], [20, 5], [30, 7]] },
                { match: 1, out: [20, 5] }
            );
        });

        it("witness: case = 0, branches = [69, 420, 1337], vals = [[10,3], [20,5], [30,7]]", async () => {
            await circuit.expectPass(
                { case: 0, branches: [69, 420, 1337], vals: [[10, 3], [20, 5], [30, 7]] },
                { match: 0, out: [0, 0] }
            );
        });

    });

});
