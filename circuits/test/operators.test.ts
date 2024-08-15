import { circomkit, WitnessTester } from "./common";

describe("operators", () => {
    describe("IsZero", () => {
        let circuit: WitnessTester<["in"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`IsZero`, {
                file: "circuits/operators",
                template: "IsZero",
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: 0", async () => {
            await circuit.expectPass(
                { in: 0 },
                { out: 1 });
        });

        it("witness: 1", async () => {
            await circuit.expectPass(
                { in: 1 },
                { out: 0 }
            );
        });

        it("witness: 42069", async () => {
            await circuit.expectPass(
                { in: 42069 },
                { out: 0 }
            );
        });
    });

    describe("IsEqual", () => {
        let circuit: WitnessTester<["in"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`IsEqual`, {
                file: "circuits/operators",
                template: "IsEqual",
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: [0,0]", async () => {
            await circuit.expectPass(
                { in: [0, 0] },
                { out: 1 }
            );
        });

        it("witness: [42069, 42069]", async () => {
            await circuit.expectPass(
                { in: [42069, 42069] },
                { out: 1 },
            );
        });

        it("witness: [42069, 0]", async () => {
            await circuit.expectPass(
                { in: [42069, 0] },
                { out: 0 },
            );
        });
    });

    describe("IsEqualArray", () => {
        let circuit: WitnessTester<["in"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`IsEqualArray`, {
                file: "circuits/operators",
                template: "IsEqualArray",
                params: [3],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: [[0,0,0],[0,0,0]]", async () => {
            await circuit.expectPass(
                { in: [[0, 0, 0], [0, 0, 0]] },
                { out: 1 }
            );
        });

        it("witness: [[1,420,69],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[1, 420, 69], [1, 420, 69]] },
                { out: 1 },
            );
        });

        it("witness: [[0,0,0],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[0, 0, 0], [1, 420, 69]] },
                { out: 0 },
            );
        });

        it("witness: [[1,420,0],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[1, 420, 0], [1, 420, 69]] },
                { out: 0 },
            );
        });

        it("witness: [[1,0,69],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[1, 0, 69], [1, 420, 69]] },
                { out: 0 },
            );
        });

        it("witness: [[0,420,69],[1,420,69]]", async () => {
            await circuit.expectPass(
                { in: [[0, 420, 69], [1, 420, 69]] },
                { out: 0 },
            );
        });
    });

    describe("Contains", () => {
        let circuit: WitnessTester<["in", "array"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`Contains`, {
                file: "circuits/operators",
                template: "Contains",
                params: [3],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: in = 0, array = [0,1,2]", async () => {
            await circuit.expectPass(
                { in: 0, array: [0, 1, 2] },
                { out: 1 }
            );
        });

        it("witness: in = 1, array = [0,1,2]", async () => {
            await circuit.expectPass(
                { in: 1, array: [0, 1, 2] },
                { out: 1 }
            );
        });

        it("witness: in = 2, array = [0,1,2]", async () => {
            await circuit.expectPass(
                { in: 2, array: [0, 1, 2] },
                { out: 1 }
            );
        });

        it("witness: in = 42069, array = [0,1,2]", async () => {
            await circuit.expectPass(
                { in: 42069, array: [0, 1, 2] },
                { out: 0 }
            );
        });

    });

    describe("ArrayAdd", () => {
        let circuit: WitnessTester<["lhs", "rhs"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`ArrayAdd`, {
                file: "circuits/operators",
                template: "ArrayAdd",
                params: [3],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: lhs = [0,1,2], rhs = [3,5,7]", async () => {
            await circuit.expectPass(
                { lhs: [0, 1, 2], rhs: [3, 5, 7] },
                { out: [3, 6, 9] }
            );
        });

    });

    describe("ArrayMul", () => {
        let circuit: WitnessTester<["lhs", "rhs"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`ArrayMul`, {
                file: "circuits/operators",
                template: "ArrayMul",
                params: [3],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: lhs = [0,1,2], rhs = [3,5,7]", async () => {
            await circuit.expectPass(
                { lhs: [0, 1, 2], rhs: [3, 5, 7] },
                { out: [0, 5, 14] }
            );
        });

    });
});
