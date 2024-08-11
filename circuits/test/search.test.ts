import { circomkit, WitnessTester } from "./common";

import witness from "../../inputs/search/witness2.json";
import { PoseidonModular } from "./common/poseidon";

describe("search", () => {
    describe("SubstringSearch", () => {
        let circuit: WitnessTester<["data", "key"], ["position"]>;

        it("witness: key at first position", async () => {
            const key = [10, 8, 9, 4];
            const data = [10, 8, 9, 4, 11, 9, 1, 2];
            const concatenatedInput = key.concat(data);
            const hashResult = PoseidonModular(concatenatedInput);

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [data.length, key.length, hashResult],
            });

            await circuit.expectPass(
                { data: data, key: key },
                { position: 0 },
            );
        });

        it("witness: key at last position", async () => {
            const key = [10, 8, 9, 4];
            const data = [11, 9, 1, 2, 10, 8, 9, 4];
            const concatenatedInput = key.concat(data);
            const hashResult = PoseidonModular(concatenatedInput);

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [data.length, key.length, hashResult],
            });

            await circuit.expectPass(
                { data: data, key: key },
                { position: 4 },
            );
        });

        it("witness: data = inputs/witness2.json:data, key = inputs2/witness.json:key, r = hash(data+key)", async () => {
            const concatenatedInput = witness["key"].concat(witness["data"]);
            const hashResult = PoseidonModular(concatenatedInput);

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringSearch",
                params: [787, 10, hashResult],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass(
                { data: witness["data"], key: witness["key"] },
                { position: 6 }
            );
        });
    });

    describe("SubstringMatchWithIndex", () => {
        let circuit: WitnessTester<["data", "key", "r", "start"]>;

        before(async () => {
            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringMatchWithIndex",
                params: [787, 10],
            });
            console.log("#constraints:", await circuit.getConstraintCount());
        });

        it("witness: data = inputs/witness2.json:data, key = inputs2/witness.json:key, r = hash(data+key)", async () => {
            await circuit.expectPass(
                { data: witness["data"], key: witness["key"], r: PoseidonModular(witness["key"].concat(witness["data"])), start: 6 },
            );
        });

        it("witness: data = inputs/witness2.json:data, key = inputs2/witness.json:key, r = hash(data+key),  incorrect position", async () => {
            await circuit.expectFail(
                { data: witness["data"], key: witness["key"], r: PoseidonModular(witness["key"].concat(witness["data"])), start: 98 },
            );
        });
    });

    describe("SubstringMatch", () => {
        let circuit: WitnessTester<["data", "key"], ["position"]>;


        it("witness: data = inputs/witness2.json:data, key = inputs2/witness.json:key, r = hash(data+key)", async () => {
            const hashResult = PoseidonModular(witness["key"].concat(witness["data"]));

            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringMatch",
                params: [787, 10, hashResult],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass(
                { data: witness["data"], key: witness["key"] },
                { position: 6 },
            );
        });

        it("witness: data = inputs/witness2.json:data, key = inputs2/witness.json:key, r = hash(data+key),  wrong hash", async () => {
            circuit = await circomkit.WitnessTester(`SubstringSearch`, {
                file: "circuits/search",
                template: "SubstringMatch",
                params: [787, 10, 10],
            });

            await circuit.expectFail(
                { data: witness["data"], key: witness["key"] },
            );
        });
    });
});