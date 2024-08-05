import { circomkit, WitnessTester } from "./common";

describe("bytes.U8ToBits", () => {
    let circuit: WitnessTester<["in"], ["out"]>;

    before(async () => {
        circuit = await circomkit.WitnessTester(`U8ToBits`, {
            file: "circuit/bytes",
            template: "U8ToBits",
        });
        console.log("#constraints:", await circuit.getConstraintCount());
    });

    it("proper witness 0", async () => {
        await circuit.expectPass({ in: 0 }, { out: [0, 0, 0, 0, 0, 0, 0, 0] });
    });

    it("proper witness 15", async () => {
        await circuit.expectPass({ in: 15 }, { out: [1, 1, 1, 1, 0, 0, 0, 0] });
    });

    it("proper witness 255", async () => {
        await circuit.expectPass({ in: 255 }, { out: [1, 1, 1, 1, 1, 1, 1, 1] });
    });

    it("failing witness 256", async () => {
        await circuit.expectFail({ in: 256 });
    });

    it("failing witness 4206942069", async () => {
        await circuit.expectFail({ in: 4206942069 });
    });
});
