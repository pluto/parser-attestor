import { circomkit, WitnessTester, generateDescription, toByte, readHTTPInputFile } from "../common";

describe("HTTP :: Locker :: Request Line", async () => {
    let circuit: WitnessTester<["data", "beginning", "middle", "final"], []>;

    function generatePassCase(input: number[], beginning: number[], middle: number[], final: number[], desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`LockStartLine`, {
                file: "circuits/http/locker",
                template: "LockStartLine",
                params: [input.length, beginning.length, middle.length, final.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, beginning: beginning, middle: middle, final: final }, {});
        });
    }

    function generateFailCase(input: number[], beginning: number[], middle: number[], final: number[], desc: string) {
        const description = generateDescription(input);

        it(`(invalid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`LockStartLine`, {
                file: "circuits/http/locker",
                template: "LockStartLine",
                params: [input.length, beginning.length, middle.length, final.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectFail({ data: input, beginning: beginning, middle: middle, final: final });
        });
    }

    describe("GET", async () => {
        let parsedHttp = readHTTPInputFile("get_request.http");
        generatePassCase(parsedHttp.input, toByte("GET"), toByte("/api"), toByte("HTTP/1.1"), "");
        generateFailCase(parsedHttp.input.slice(0), toByte("POST"), toByte("/api"), toByte("HTTP/1.1"), "");
        generateFailCase(parsedHttp.input.slice(0), toByte("GET"), toByte("/"), toByte("HTTP/1.1"), "");
        generateFailCase(parsedHttp.input.slice(0), toByte("GET"), toByte("/api"), toByte("HTTP"), "");
    });

    describe("POST", async () => {
        let parsedHttp = readHTTPInputFile("post_request.http");
        generatePassCase(parsedHttp.input, toByte("POST"), toByte("/contact_form.php"), toByte("HTTP/1.1"), "");
        generateFailCase(parsedHttp.input.slice(0), toByte("GET"), toByte("/contact_form.php"), toByte("HTTP/1.1"), "");
        generateFailCase(parsedHttp.input.slice(0), toByte("POST"), toByte("/"), toByte("HTTP/1.1"), "");
        generateFailCase(parsedHttp.input.slice(0), toByte("POST"), toByte("/contact_form.php"), toByte("HTTP"), "");
    });
});

describe("HTTP :: Locker :: Status Line", async () => {
    let circuit: WitnessTester<["data", "beginning", "middle", "final"], []>;

    function generatePassCase(input: number[], beginning: number[], middle: number[], final: number[], desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`LockStartLine`, {
                file: "circuits/http/locker",
                template: "LockStartLine",
                params: [input.length, beginning.length, middle.length, final.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, beginning: beginning, middle: middle, final: final }, {});
        });
    }

    function generateFailCase(input: number[], beginning: number[], middle: number[], final: number[], desc: string) {
        const description = generateDescription(input);

        it(`(invalid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`LockStartLine`, {
                file: "circuits/http/locker",
                template: "LockStartLine",
                params: [input.length, beginning.length, middle.length, final.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectFail({ data: input, beginning: beginning, middle: middle, final: final });
        });
    }

    describe("GET", async () => {
        let parsedHttp = readHTTPInputFile("get_response.http");
        generatePassCase(parsedHttp.input, toByte("HTTP/1.1"), toByte("200"), toByte("OK"), "");
        generateFailCase(parsedHttp.input, toByte("HTTP"), toByte("200"), toByte("OK"), "");
        generateFailCase(parsedHttp.input, toByte("HTTP/1.1"), toByte("404"), toByte("OK"), "");
        generateFailCase(parsedHttp.input, toByte("HTTP/1.1"), toByte("200"), toByte("Not Found"), "");
    });
});