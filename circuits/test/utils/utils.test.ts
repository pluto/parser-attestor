import { circomkit, WitnessTester } from "../common";

describe("ASCII", () => {
    let circuit: WitnessTester<["in"], ["out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`ASCII`, {
            file: "circuits/utils",
            template: "ASCII",
            params: [13],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    it("(valid) witness: in = b\"Hello, world!\"", async () => {
        await circuit.expectPass(
            { in: [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33] },
        );
    });

    it("(invalid) witness: in = [256, ...]", async () => {
        await circuit.expectFail(
            { in: [256, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33] }
        );
    });
});

describe("IsEqualArray", () => {
    let circuit: WitnessTester<["in"], ["out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`IsEqualArray`, {
            file: "circuits/utils",
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
            file: "circuits/utils",
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
            file: "circuits/utils",
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
            file: "circuits/utils",
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
            file: "circuits/utils",
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

describe("InRange", () => {
    let circuit: WitnessTester<["in", "range"], ["out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`InRange`, {
            file: "circuits/utils",
            template: "InRange",
            params: [8],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    it("witness: in = 1, range = [0,2]", async () => {
        await circuit.expectPass(
            { in: 1, range: [0, 2] },
            { out: 1 }
        );
    });

    it("witness: in = 69, range = [128,255]", async () => {
        await circuit.expectPass(
            { in: 69, range: [128, 255] },
            { out: 0 }
        );
    });

    it("witness: in = 200, range = [128,255]", async () => {
        await circuit.expectPass(
            { in: 1, range: [0, 2] },
            { out: 1 }
        );
    });
});

describe("Switch", () => {
    let circuit: WitnessTester<["case", "branches", "vals"], ["match", "out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`Switch`, {
            file: "circuits/utils",
            template: "Switch",
            params: [3],
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    it("witness: case = 0, branches = [0, 1, 2], vals = [69, 420, 1337]", async () => {
        await circuit.expectPass(
            { case: 0, branches: [0, 1, 2], vals: [69, 420, 1337] },
            { match: 1, out: 69 },
        );
    });

    it("witness: case = 1, branches = [0, 1, 2], vals = [69, 420, 1337]", async () => {
        await circuit.expectPass(
            { case: 1, branches: [0, 1, 2], vals: [69, 420, 1337] },
            { match: 1, out: 420 },
        );
    });

    it("witness: case = 2, branches = [0, 1, 2], vals = [69, 420, 1337]", async () => {
        await circuit.expectPass(
            { case: 2, branches: [0, 1, 2], vals: [69, 420, 1337] },
            { match: 1, out: 1337 },
        );
    });

    it("witness: case = 3, branches = [0, 1, 2], vals = [69, 420, 1337]", async () => {
        await circuit.expectPass(
            { case: 3, branches: [0, 1, 2], vals: [69, 420, 1337] },
            { match: 0, out: 0 },
        );
    });


});

describe("SwitchArray", () => {
    let circuit: WitnessTester<["case", "branches", "vals"], ["match", "out"]>;
    before(async () => {
        circuit = await circomkit.WitnessTester(`SwitchArray`, {
            file: "circuits/utils",
            template: "SwitchArray",
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

