import { circomkit, WitnessTester, readHTTPInputFile, toByte } from "../common";
import { join } from "path";
import { spawn } from "child_process";
import { readFileSync } from "fs";

function readLockFile<T>(filename: string): T {
    const filePath = join(__dirname, "..", "..", "..", "examples", "http", "lockfile", filename);
    const jsonString = readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(jsonString);
    return jsonData;
}

function getHeaders(data: Request | Response): [string, string][] {
    const headers: [string, string][] = [];
    let i = 1;
    while (true) {
        const nameKey = `headerName${i}`;
        const valueKey = `headerValue${i}`;
        if (nameKey in data && valueKey in data) {
            headers.push([data[nameKey], data[valueKey]]);
            i++;
        } else {
            break;
        }
    }
    return headers;
}

interface Request {
    method: string,
    target: string,
    version: string,
    [key: string]: string,
}

interface Response {
    version: string,
    status: string,
    message: string,
    [key: string]: string,
}


function executeCodegen(inputFilename: string, outputFilename: string) {
    return new Promise((resolve, reject) => {
        const inputPath = join(__dirname, "..", "..", "..", "examples", "http", "lockfile", inputFilename);

        const codegen = spawn("cargo", ["run", "http", "--lockfile", inputPath, "--output-filename", outputFilename]);

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

describe("HTTP :: Codegen :: Request", async () => {
    let circuit: WitnessTester<["data", "method", "target", "version", "header1", "value1", "header2", "value2"], []>;

    it("(valid) GET:", async () => {
        let lockfile = "request.lock";
        let inputfile = "get_request.http";

        // generate extractor circuit using codegen
        await executeCodegen(`${lockfile}.json`, lockfile);

        const lockData = readLockFile<Request>(`${lockfile}.json`);
        console.log("lockData: ", JSON.stringify(lockData));

        const input = readHTTPInputFile(`${inputfile}`).input;

        const headers = getHeaders(lockData);
        const params = [input.length, lockData.method.length, lockData.target.length, lockData.version.length];
        headers.forEach(header => {
            params.push(header[0].length);
            params.push(header[1].length);
        });


        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `main/${lockfile}`,
            template: "LockHTTPRequest",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        // match circuit output to original JSON value
        const circuitInput: any = {
            data: input,
            method: toByte(lockData.method),
            target: toByte(lockData.target),
            version: toByte(lockData.version),
        };

        headers.forEach((header, index) => {
            circuitInput[`header${index + 1}`] = toByte(header[0]);
            circuitInput[`value${index + 1}`] = toByte(header[1]);
        });
        await circuit.expectPass(circuitInput, {});
    });

    it("(invalid) GET:", async () => {
        let lockfile = "request.lock";
        let inputfile = "get_request.http";

        // generate extractor circuit using codegen
        await executeCodegen(`${lockfile}.json`, lockfile);

        const lockData = readLockFile<Request>(`${lockfile}.json`);

        const input = readHTTPInputFile(`${inputfile}`).input

        const headers = getHeaders(lockData);
        const params = [input.length, lockData.method.length, lockData.target.length, lockData.version.length];
        headers.forEach(header => {
            params.push(header[0].length);
            params.push(header[1].length);
        });


        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `main/${lockfile}`,
            template: "LockHTTPRequest",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        const circuitInput: any = {
            data: input,
            method: toByte(lockData.method),
            target: toByte(lockData.target),
            version: toByte(lockData.version),
        };

        headers.forEach((header, index) => {
            circuitInput[`header${index + 1}`] = toByte(header[0]);
            circuitInput[`value${index + 1}`] = toByte(header[1]);
        });

        circuitInput.value1 = toByte("/aip");
        await circuit.expectFail(circuitInput);
    });
});

describe("HTTP :: Codegen :: Response", async () => {
    let circuit: WitnessTester<["data", "version", "status", "message", "header1", "value1", "header2", "value2"], ["body"]>;

    it("(valid) GET:", async () => {
        let lockfile = "response.lock";
        let inputfile = "get_response.http";

        // generate extractor circuit using codegen
        await executeCodegen(`${lockfile}.json`, lockfile);

        const lockData = readLockFile<Response>(`${lockfile}.json`);
        console.log("lockData: ", JSON.stringify(lockData));

        const http = readHTTPInputFile(`${inputfile}`);
        const input = http.input;

        const headers = getHeaders(lockData);

        const params = [input.length, parseInt(http.headers["Content-Length"]), lockData.version.length, lockData.status.length, lockData.message.length];
        headers.forEach(header => {
            params.push(header[0].length);
            params.push(header[1].length);
        });


        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `main/${lockfile}`,
            template: "LockHTTPResponse",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        // match circuit output to original JSON value
        const circuitInput: any = {
            data: input,
            version: toByte(lockData.version),
            status: toByte(lockData.status),
            message: toByte(lockData.message),
        };

        headers.forEach((header, index) => {
            circuitInput[`header${index + 1}`] = toByte(header[0]);
            circuitInput[`value${index + 1}`] = toByte(header[1]);
        });


        await circuit.expectPass(circuitInput, { body: http.bodyBytes });
    });

    it("(invalid) GET:", async () => {
        let lockfile = "response.lock";
        let inputfile = "get_response.http";

        // generate extractor circuit using codegen
        await executeCodegen(`${lockfile}.json`, lockfile);

        const lockData = readLockFile<Response>(`${lockfile}.json`);

        const http = readHTTPInputFile(`${inputfile}`);
        const input = http.input;

        const headers = getHeaders(lockData);

        const params = [input.length, parseInt(http.headers["Content-Length"]), lockData.version.length, lockData.status.length, lockData.message.length];
        headers.forEach(header => {
            params.push(header[0].length);
            params.push(header[1].length);
        });


        circuit = await circomkit.WitnessTester(`Extract`, {
            file: `main/${lockfile}`,
            template: "LockHTTPResponse",
            params: params,
        });
        console.log("#constraints:", await circuit.getConstraintCount());

        const circuitInput: any = {
            data: input,
            version: toByte(lockData.version),
            status: toByte(lockData.status),
            message: toByte(lockData.message),
        };

        headers.forEach((header, index) => {
            circuitInput[`header${index + 1}`] = toByte(header[0]);
            circuitInput[`value${index + 1}`] = toByte(header[1]);
        });

        circuitInput.value1 = toByte("/aip");
        await circuit.expectFail(circuitInput);
    });
});