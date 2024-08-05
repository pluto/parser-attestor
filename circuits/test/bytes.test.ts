import { circomkit, WitnessTester } from "./common";

describe("bytes", () => {
    let circuit: WitnessTester<["in"], ["out"]>;

    describe("U8ToBits", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`U8ToBits`, {
                file: "circuits/bytes",
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

    describe("ASCII", () => {
        before(async () => {
            circuit = await circomkit.WitnessTester(`ASCII`, {
                file: "circuits/bytes",
                template: "ASCII",
                params: [13],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("Valid ASCII input", async () => {
            await circuit.expectPass(
                { in: [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33] },
                { out: [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33] }
            );
        });

        it("Invalid ASCII input", async () => {
            await circuit.expectFail(
                { in: [256, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33] }
            );
        });
    });
});
