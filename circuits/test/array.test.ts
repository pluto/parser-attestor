import { circomkit, WitnessTester } from "./common";

describe("array", () => {
    describe("Slice", () => {
        let circuit: WitnessTester<["in"], ["out"]>;
        before(async () => {
            circuit = await circomkit.WitnessTester(`Slice`, {
                file: "circuits/utils/array",
                template: "Slice",
                params: [10, 2, 4],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: [random*10], start: 2, end: 4", async () => {
            const input = Array.from({ length: 10 }, () => Math.floor(Math.random() * 256));
            await circuit.expectPass(
                { in: input },
                { out: input.slice(2, 4) }
            );
        });

        it("witness: [random*9], start: 2, end: 4", async () => {
            const input = Array.from({ length: 9 }, () => Math.floor(Math.random() * 256));
            await circuit.expectFail(
                { in: input },
            );
        });
    });
});