use crate::{
    circuit_config::{write_config, CircomkitCircuitConfig},
    codegen::{
        http::{parse_http_file, HttpData},
        json::{json_max_stack_height, Key, Lockfile as JsonLockfile, ValueType},
    },
    witness::read_input_file_as_bytes,
    ExtractorArgs,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::path::Path;

use super::{http::http_circuit_from_lockfile, json::json_circuit_from_lockfile};

#[derive(Debug, Serialize, Deserialize)]
pub struct ExtendedLockfile {
    http: HttpData,
    json: JsonLockfile,
}

fn build_integrated_circuit(
    http_data: &HttpData,
    http_circuit_config: &CircomkitCircuitConfig,
    json_lockfile: &JsonLockfile,
    json_circuit_config: &CircomkitCircuitConfig,
    output_filename: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut circuit_buffer = String::new();

    circuit_buffer += "pragma circom 2.1.9;\n\n";

    let http_circuit_filename = Path::new(&http_circuit_config.file)
        .file_name()
        .expect("incorrect filepath in circuit config")
        .to_str()
        .expect("improper circuit filename");

    let json_circuit_filename = Path::new(&json_circuit_config.file)
        .file_name()
        .expect("incorrect filepath in circuit config")
        .to_str()
        .expect("improper circuit filename");

    circuit_buffer += &format!("include \"./{}\";\n", http_circuit_filename);
    circuit_buffer += &format!("include\"./{}\";\n\n", json_circuit_filename);

    let http_params = http_data.params();

    let mut json_params = json_lockfile.params();
    json_params.remove(0);

    circuit_buffer += &format!(
        "template HttpJson({}{}) {{\n",
        http_params.join(", "),
        json_params.join(", ")
    );

    {
        circuit_buffer += r#"
    // Raw HTTP bytestream
    signal input data[DATA_BYTES];
"#;

        // Start line signals
        {
            match http_data {
                HttpData::Request(_) => {
                    circuit_buffer += r#"
    // Request line attributes
    signal input method[methodLen];
    signal input target[targetLen];
    signal input version[versionLen];

"#;
                }
                HttpData::Response(_) => {
                    circuit_buffer += r#"
    // Status line attributes
    signal input version[versionLen];
    signal input status[statusLen];
    signal input message[messageLen];

"#;
                }
            }
        }

        // Header signals
        circuit_buffer += "    // Header names and values to lock\n";
        for (i, _header) in http_data.headers().iter().enumerate() {
            circuit_buffer += &format!(
                "    signal input header{}[headerNameLen{}];\n",
                i + 1,
                i + 1
            );
            circuit_buffer += &format!(
                "    signal input value{}[headerValueLen{}];\n",
                i + 1,
                i + 1
            );
        }
    }

    circuit_buffer += "\n    signal httpBody[maxContentLength];\n\n";
    circuit_buffer += &format!(
        "    httpBody <== {}({})(httpData, ",
        http_circuit_config.template,
        http_params.join(", "),
    );

    let mut http_inputs = http_data.inputs();
    http_inputs.remove(0);
    circuit_buffer += &http_inputs.join(", ");
    circuit_buffer += ");\n\n";

    for (i, key) in json_lockfile.keys.iter().enumerate() {
        match key {
            Key::String(_) => {
                circuit_buffer += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1)
            }
            Key::Num(_) => (),
        }
    }

    circuit_buffer += "\n    signal output value[maxValueLen]\n";
    circuit_buffer += &format!(
        "    value <== {}(maxContentLength, {}",
        json_circuit_config.template,
        json_params.join(", ")
    );

    let json_inputs = json_lockfile.inputs();
    circuit_buffer += &format!(")(httpBody, {});\n", json_inputs.join(", "));

    circuit_buffer += "}";

    // write circuits to file
    let mut file_path = std::env::current_dir()?;
    file_path.push("circuits");
    file_path.push("main");

    // create dir if doesn't exist
    std::fs::create_dir_all(&file_path)?;

    file_path.push(format!("{}.circom", output_filename));

    std::fs::write(&file_path, circuit_buffer)?;

    println!("Code generated at: {}", file_path.display());

    Ok(())
}

fn build_circuit_config(
    args: &ExtractorArgs,
    http_data: &HttpData,
    json_lockfile: &JsonLockfile,
    output_filename: &str,
) -> Result<CircomkitCircuitConfig, Box<dyn std::error::Error>> {
    let input = read_input_file_as_bytes(&crate::FileType::Http, &args.input_file)?;

    let (_, http_body) = parse_http_file(http_data, input.clone())?;

    let mut params = vec![input.len()];

    match http_data {
        HttpData::Request(request) => {
            params.push(request.method.len());
            params.push(request.target.len());
            params.push(request.version.len());
            for (key, value) in request.headers.iter() {
                params.push(key.len());
                params.push(value.len());
            }
        }
        HttpData::Response(response) => {
            params.push(http_body.len());
            params.push(response.version.len());
            params.push(response.status.len());
            params.push(response.message.len());
            for (key, value) in response.headers.iter() {
                params.push(key.len());
                params.push(value.len());
            }
        }
    }

    params.push(json_max_stack_height(&http_body));

    let mut current_value: Value = serde_json::from_slice(&http_body)?;
    for (i, key) in json_lockfile.keys.iter().enumerate() {
        match key {
            Key::String(key) => {
                if let Some(value) = current_value.get_mut(key) {
                    // update circuit params
                    params.push(key.len());

                    // update current object value inside key
                    current_value = value.to_owned();
                } else {
                    return Err(String::from("provided key not present in input JSON").into());
                }
            }
            Key::Num(index) => {
                if let Some(value) = current_value.get_mut(index) {
                    params.push(*index);
                    current_value = value.to_owned();
                } else {
                    return Err(String::from("provided index not present in input JSON").into());
                }
            }
        }
        params.push(i);
    }

    // get value of specified key
    // Currently only supports number, string
    let value_bytes = match json_lockfile.value_type {
        ValueType::Number => {
            if !current_value.is_u64() {
                return Err(String::from("value type doesn't match").into());
            }
            current_value.as_u64().unwrap().to_string()
        }
        ValueType::String => {
            if !current_value.is_string() {
                return Err(String::from("value type doesn't match").into());
            }
            current_value.as_str().unwrap().to_string()
        }
    };
    params.push(value_bytes.as_bytes().len());

    Ok(CircomkitCircuitConfig {
        file: format!("main/{}", output_filename),
        template: String::from("HttpJson"),
        params,
    })
}

pub fn integrated_circuit(args: &ExtractorArgs) -> Result<(), Box<dyn std::error::Error>> {
    let extended_lockfile: ExtendedLockfile =
        serde_json::from_slice(&std::fs::read(&args.lockfile)?)?;

    let http_data: HttpData = extended_lockfile.http;
    let lockfile: JsonLockfile = extended_lockfile.json;

    let http_circuit_filename = format!("{}_http", args.circuit_name);
    let http_circuit_config = http_circuit_from_lockfile(
        &args.input_file,
        &http_data,
        &http_circuit_filename,
        args.debug,
    )?;

    // read http response body as json input
    let json_circuit_filename = format!("{}_json", args.circuit_name);
    let input = read_input_file_as_bytes(&crate::FileType::Http, &args.input_file)?;
    let (_, http_body) = parse_http_file(&http_data, input.clone())?;

    let json_circuit_config =
        json_circuit_from_lockfile(&http_body, &lockfile, &json_circuit_filename, args.debug)?;

    let config = build_circuit_config(args, &http_data, &lockfile, &args.circuit_name)?;

    build_integrated_circuit(
        &http_data,
        &http_circuit_config,
        &lockfile,
        &json_circuit_config,
        &args.circuit_name,
    )?;

    write_config(&args.circuit_name, &config)?;

    Ok(())
}
