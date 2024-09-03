import 'mocha';
import { readFileSync } from "fs";
import { join } from "path";
import { Circomkit, WitnessTester } from "circomkit";

export const circomkit = new Circomkit({
    verbose: false,
});

export { WitnessTester };

function stringifyValue(value: any): string {
    if (Array.isArray(value)) {
        return `[${value.map(stringifyValue).join(', ')}]`;
    }
    if (typeof value === 'object' && value !== null) {
        return `{${Object.entries(value).map(([k, v]) => `${k}: ${stringifyValue(v)}`).join(', ')}}`;
    }
    return String(value);
}

export function generateDescription(input: any): string {
    return Object.entries(input)
        .map(([key, value]) => `${key} = ${stringifyValue(value)}`)
        .join(", ");
}

export function readJSONInputFile(filename: string, key: any[]): [number[], number[][], number[]] {
    const valueStringPath = join(__dirname, "..", "..", "..", "examples", "json", "test", filename);

    let input: number[] = [];
    let output: number[] = [];

    let data = readFileSync(valueStringPath, 'utf-8');

    let keyUnicode: number[][] = [];
    for (let i = 0; i < key.length; i++) {
        keyUnicode[i] = [];
        let key_string = key[i].toString();
        for (let j = 0; j < key_string.length; j++) {
            keyUnicode[i].push(key_string.charCodeAt(j));
        }
    }

    const byteArray = [];
    for (let i = 0; i < data.length; i++) {
        byteArray.push(data.charCodeAt(i));
    }
    input = byteArray;

    let jsonFile = JSON.parse(data);
    let value: string = key.reduce((acc, key) => acc && acc[key], jsonFile).toString();
    for (let i = 0; i < value.length; i++) {
        output.push(value.charCodeAt(i));
    }

    return [input, keyUnicode, output];
}

export function toByte(data: string): number[] {
    const byteArray = [];
    for (let i = 0; i < data.length; i++) {
        byteArray.push(data.charCodeAt(i));
    }
    return byteArray
}

export function readHTTPInputFile(filename: string) {
    const filePath = join(__dirname, "..", "..", "..", "examples", "http", filename);
    let input: number[] = [];

    let data = readFileSync(filePath, 'utf-8');

    input = toByte(data);

    // Split headers and body
    const [headerSection, bodySection] = data.split('\r\n\r\n');

    // Function to parse headers into a dictionary
    function parseHeaders(headerLines: string[]) {
        const headers: { [id: string]: string } = {};

        headerLines.forEach(line => {
            const [key, value] = line.split(/:\s(.+)/);
            headers[key] = value ? value : '';
        });

        return headers;
    }

    // Parse the headers
    const headerLines = headerSection.split('\r\n');
    const initialLine = headerLines[0].split(' ');
    const headers = parseHeaders(headerLines.slice(1));

    // Parse the body, if JSON response
    let responseBody = {};
    if (headers["Content-Type"] == "application/json") {
        responseBody = JSON.parse(bodySection);
    }

    // Combine headers and body into an object
    return {
        input: input,
        initialLine: initialLine,
        headers: headers,
        body: responseBody,
        bodyBytes: toByte(bodySection),
    };
}