import { circomkit, WitnessTester } from "../common";
describe("IsEqualArray", () => {
    let circuit: WitnessTester<["in"], ["out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`IsEqualArray`, {
            file: "utils/array",
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
            file: "utils/array",
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
            file: "utils/array",
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
            file: "utils/array",
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

describe("GenericArrayAdd", () => {
    let circuit: WitnessTester<["arrays"], ["out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`ArrayAdd`, {
            file: "utils/array",
            template: "GenericArrayAdd",
            params: [3, 2],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    it("witness: arrays = [[0,1,2],[3,5,7]]", async () => {
        await circuit.expectPass(
            { arrays: [[0, 1, 2], [3, 5, 7]] },
            { out: [3, 6, 9] }
        );
    });

});