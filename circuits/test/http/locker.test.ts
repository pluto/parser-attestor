import { circomkit, WitnessTester, generateDescription, toByte, readHTTPInputFile } from "../common";

describe("HTTP :: Locker :: RequestLine", async () => {
    let circuit: WitnessTester<["data", "method", "target", "version"], []>;

    function generatePassCase(input: number[], method: number[], target: number[], version: number[], desc: string) {
        const description = generateDescription(input);

        it(`(valid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`LockRequestLineData`, {
                file: "circuits/http/locker",
                template: "LockRequestLineData",
                params: [input.length, method.length, target.length, version.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectPass({ data: input, method: method, target: target, version: version }, {});
        });
    }

    function generateFailCase(input: number[], method: number[], target: number[], version: number[], desc: string) {
        const description = generateDescription(input);

        it(`(invalid) witness: ${description} ${desc}`, async () => {
            circuit = await circomkit.WitnessTester(`LockRequestLineData`, {
                file: "circuits/http/locker",
                template: "LockRequestLineData",
                params: [input.length, method.length, target.length, version.length],
            });
            console.log("#constraints:", await circuit.getConstraintCount());

            await circuit.expectFail({ data: input, method: method, target: target, version: version });
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