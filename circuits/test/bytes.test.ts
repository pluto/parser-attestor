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

        it("(valid) witness: in = 0", async () => {
            await circuit.expectPass({ in: 0 });
        });

        it("(valid) witness: in = 15", async () => {
            await circuit.expectPass({ in: 15 });
        });

        it("(valid) witness: in = 255", async () => {
            await circuit.expectPass({ in: 255 });
        });

        it("(invalid) witness: in = 256", async () => {
            await circuit.expectFail({ in: 256 });
        });

        it("(invalid) witness: in = 42069", async () => {
            await circuit.expectFail({ in: 42069 });
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
});
