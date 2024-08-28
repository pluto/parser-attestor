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

export function readInputFile(filename: string, key: any[]): [number[], number[][], number[]] {
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