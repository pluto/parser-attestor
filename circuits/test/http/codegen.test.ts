import { circomkit, WitnessTester, readHTTPInputFile, toByte } from "../common";
import { join } from "path";
import { spawn } from "child_process";
import { readFileSync } from "fs";

function readLockFile(filename: string): HttpData {
    const filePath = join(__dirname, "..", "..", "..", "examples", "lockfile", filename);
    const jsonString = readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(jsonString);
    return jsonData;
}

interface HttpData {
    request: Request;
    response: Response;
}

interface Request {
    method: string,
    target: string,
    version: string,
    headers: [string, string][],
}

interface Response {
    version: string,
    status: string,
    message: string,
    headers: [string, string][],
}


function executeCodegen(inputFilename: string, outputFilename: string) {
    return new Promise((resolve, reject) => {
        const inputPath = join(__dirname, "..", "..", "..", "examples", "lockfile", inputFilename);

        const codegen = spawn("cargo", ["run", "http-lock", "--lockfile", inputPath, "--output-filename", outputFilename]);

        codegen.stdout.on('data', (data) => {
            console.log(`stdout: ${data}`);
        });

        codegen.stderr.on('data', (data) => {
            console.error(`stderr: ${data}`);
        });

        codegen.on('close', (code) => {
            if (code === 0) {
                resolve(`child process exited with code ${code}`); // Resolve the promise if the process exits successfully
            } else {
                reject(new Error(`Process exited with code ${code}`)); // Reject if there's an error
            }
        });
    });
}

describe("HTTP :: Codegen", async () => {
    let circuit: WitnessTester<["data", "beginning", "middle", "final", "header1", "value1", "header2", "value2"], []>;

    it("(valid) get_request:", async () => {
        let lockfile = "test.lock";
        let inputfile = "get_request.http";

        // generate extractor circuit using codegen
        await executeCodegen(`${lockfile}.json`, lockfile);

        const lockData = await readLockFile(`${lockfile}.json`);
        console.log("lockData: ", JSON.stringify(lockData));

        const input = await readHTTPInputFile(`${inputfile}`).input

        const params = [input.length, lockData.request.method.length, lockData.request.target.length, lockData.request.version.length];
        lockData.request.headers.forEach(header => {
            params.push(header[0].length);  // Header name length
            params.push(header[1].length);  // Header value length
            console.log("header: ", header[0]);
            console.log("value: ", header[1]);
        });


        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${lockfile}`,
            template: "LockHTTP",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        // match circuit output to original JSON value
        await circuit.expectPass({
            data: input,
            beginning: toByte(lockData.request.method),
            middle: toByte(lockData.request.target),
            final: toByte(lockData.request.version),
            header1: toByte(lockData.request.headers[0][0]),
            value1: toByte(lockData.request.headers[0][1]),
            header2: toByte(lockData.request.headers[1][0]),
            value2: toByte(lockData.request.headers[1][1])
        },
            {}
        );
    });

    it("(invalid) get_request:", async () => {
        let lockfile = "test.lock";
        let inputfile = "get_request.http";

        // generate extractor circuit using codegen
        await executeCodegen(`${lockfile}.json`, lockfile);

        const lockData = await readLockFile(`${lockfile}.json`);

        const input = await readHTTPInputFile(`${inputfile}`).input

        const params = [input.length, lockData.request.method.length, lockData.request.target.length, lockData.request.version.length];
        lockData.request.headers.forEach(header => {
            params.push(header[0].length);  // Header name length
            params.push(header[1].length);  // Header value length
        });


        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `circuits/main/${lockfile}`,
            template: "LockHTTP",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        await circuit.expectFail({
            data: input.slice(0),
            beginning: toByte(lockData.request.method),
            middle: toByte(lockData.request.target),
            final: toByte(lockData.request.version),
            header1: toByte(lockData.request.headers[0][0]),
            value1: toByte("/aip"),
            header2: toByte(lockData.request.headers[1][0]),
            value2: toByte(lockData.request.headers[1][1])
        });
    });
});
