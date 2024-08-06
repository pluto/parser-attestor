import { circomkit, WitnessTester } from "./common";

describe("operators", () => {
    let circuit: WitnessTester<["in"], ["out"]>;

    describe("IsZero", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`IsZero`, {
                file: "circuits/operators",
                template: "IsZero",
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness 0", async () => {
            await circuit.expectPass(
                { in: 0 },
                { out: 1 });
        });

        it("witness 1", async () => {
            await circuit.expectPass(
                { in: 1 },
                { out: 0 }
            );
        });

        it("witness 42069", async () => {
            await circuit.expectPass(
                { in: 42069 },
                { out: 0 }
            );
        });
    });

    describe("IsEqual", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`IsEqual`, {
                file: "circuits/operators",
                template: "IsEqual",
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness [0,0]", async () => {
            await circuit.expectPass(
                { in: [0, 0] },
                { out: 1 }
            );
        });

        it("witness [42069, 42069]", async () => {
            await circuit.expectPass(
                { in: [42069, 42069] },
                { out: 1 },
            );
        });

        it("witness [42069, 0]", async () => {
            await circuit.expectPass(
                { in: [42069, 0] },
                { out: 0 },
            );
        });
    });

    describe("IsEqualArray", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`IsEqualArray`, {
                file: "circuits/operators",
                template: "IsEqualArray",
                params: [3],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness [[0,0,0],[0,0,0]]", async () => {
            await circuit.expectPass(
                { in: [[0, 0, 0], [0, 0, 0]] },
                { out: 1 }
            );
        });

        it("witness [[1,420,69],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[1, 420, 69], [1, 420, 69]] },
                { out: 1 },
            );
        });

        it("witness [[0,0,0],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[0, 0, 0], [1, 420, 69]] },
                { out: 0 },
            );
        });

        it("witness [[1,420,0],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[1, 420, 0], [1, 420, 69]] },
                { out: 0 },
            );
        });

        it("witness [[1,0,69],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[1, 0, 69], [1, 420, 69]] },
                { out: 0 },
            );
        });

        it("witness [[0,420,69],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[0, 420, 69], [1, 420, 69]] },
                { out: 0 },
            );
        });
    });
});
