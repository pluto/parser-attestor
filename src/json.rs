use super::*;
use std::{
    cmp::max_by,
    collections::HashMap,
    fs::{self, create_dir_all},
    str::FromStr,
};

use codegen::{write_circuit_config, CircomkitCircuitsInput};
use serde_json::Value;

#[derive(Debug, Deserialize)]
pub enum ValueType {
    #[serde(rename = "string")]
    String,
    #[serde(rename = "number")]
    Number,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Key {
    String(String),
    Num(usize),
}

#[derive(Debug, Deserialize)]
pub struct JsonLockfile {
    keys: Vec<Key>,
    value_type: ValueType,
}

impl JsonLockfile {
    pub fn as_bytes(&self) -> HashMap<String, Vec<u8>> {
        let mut keys = HashMap::<String, Vec<u8>>::new();
        for (i, key) in self.keys.iter().enumerate() {
            if let Key::String(key) = key {
                let key_name = format!("key{}", i + 1);
                keys.insert(key_name, key.as_bytes().to_vec());
            }
        }
        keys
    }
}

fn extract_string(data: &JsonLockfile, circuit_buffer: &mut String, debug: bool) {
    *circuit_buffer += "template ExtractStringValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => *circuit_buffer += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
            Key::Num(_) => *circuit_buffer += &format!("index{}, depth{}, ", i + 1, i + 1),
        }
    }
    *circuit_buffer += "maxValueLen) {\n";

    *circuit_buffer += "    signal input data[DATA_BYTES];\n\n";

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => {
                *circuit_buffer += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1)
            }
            Key::Num(_) => (),
        }
    }

    *circuit_buffer += r#"
    signal output value[maxValueLen];

    signal value_starting_index[DATA_BYTES];
"#;

    // value_starting_index <== ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen)(data, key1, key2);
    {
        *circuit_buffer +=
            "    value_starting_index <== ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *circuit_buffer += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
                Key::Num(_) => *circuit_buffer += &format!("index{}, depth{}, ", i + 1, i + 1),
            }
        }
        *circuit_buffer += "maxValueLen)(data, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *circuit_buffer += &format!("key{}, ", i + 1),
                Key::Num(_) => (),
            }
        }
        circuit_buffer.pop();
        circuit_buffer.pop();
        *circuit_buffer += ");\n";
    }

    *circuit_buffer += r#"
    value <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2]+1, maxValueLen);"#;

    if debug {
        *circuit_buffer += r#"
    log("value_starting_index", value_starting_index[DATA_BYTES-2]);
    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value[i]);
    }"#;
    }

    *circuit_buffer += r#"
}
"#;
}

fn extract_number(data: &JsonLockfile, circuit_buffer: &mut String, debug: bool) {
    *circuit_buffer += "template ExtractNumValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => *circuit_buffer += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
            Key::Num(_) => *circuit_buffer += &format!("index{}, depth{}, ", i + 1, i + 1),
        }
    }
    *circuit_buffer += "maxValueLen) {\n";

    *circuit_buffer += "    signal input data[DATA_BYTES];\n\n";

    for (i, key) in data.keys.iter().enumerate() {
        match key {
            Key::String(_) => {
                *circuit_buffer += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1)
            }
            Key::Num(_) => (),
        }
    }

    *circuit_buffer += r#"
    signal value_string[maxValueLen];
    signal output value;

    signal value_starting_index[DATA_BYTES];
"#;

    // value_starting_index <== ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, keyLen2, depth2, index3, depth3, index4, depth4, maxValueLen)(data, key1, key2);
    {
        *circuit_buffer +=
            "    value_starting_index <== ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *circuit_buffer += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
                Key::Num(_) => *circuit_buffer += &format!("index{}, depth{}, ", i + 1, i + 1),
            }
        }
        *circuit_buffer += "maxValueLen)(data, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => *circuit_buffer += &format!("key{}, ", i + 1),
                Key::Num(_) => (),
            }
        }
        circuit_buffer.pop();
        circuit_buffer.pop();
        *circuit_buffer += ");\n";
    }

    *circuit_buffer += r#"
    value_string <== SelectSubArray(DATA_BYTES, maxValueLen)(data, value_starting_index[DATA_BYTES-2], maxValueLen);
"#;

    if debug {
        *circuit_buffer += r#"
    log("value_starting_index", value_starting_index[DATA_BYTES-2]);
    for (var i=0 ; i<maxValueLen; i++) {
        log("value[",i,"]=", value_string[i]);
    }"#;
    }

    *circuit_buffer += r#"

    signal number_value[maxValueLen];
    number_value[0] <== (value_string[0]-48);
    for (var i=1 ; i<maxValueLen ; i++) {
        number_value[i] <== number_value[i-1] * 10 + (value_string[i]-48);
    }

    value <== number_value[maxValueLen-1];
}
"#;
}

fn build_json_circuit(
    data: &JsonLockfile,
    output_filename: &String,
    debug: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut circuit_buffer = String::new();

    // Dump out the contents of the lockfile used into the circuit
    circuit_buffer += "/*\n";
    circuit_buffer += &format!("{:#?}", data);
    circuit_buffer += "\n*/\n";

    circuit_buffer += "pragma circom 2.1.9;\n\n";
    circuit_buffer += "include \"../json/interpreter.circom\";\n\n";

    // template ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1, index2, depth2, keyLen3, depth3, index4, depth4, maxValueLen) {
    {
        circuit_buffer += "template ExtractValue(DATA_BYTES, MAX_STACK_HEIGHT, ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => circuit_buffer += &format!("keyLen{}, depth{}, ", i + 1, i + 1),
                Key::Num(_) => circuit_buffer += &format!("index{}, depth{}, ", i + 1, i + 1),
            }
        }
        circuit_buffer += "maxValueLen) {\n";
    }

    /*
    signal input data[DATA_BYTES];

    signal input key1[keyLen1];
    signal input key3[keyLen3];
     */
    {
        circuit_buffer += "    signal input data[DATA_BYTES];\n\n";

        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => {
                    circuit_buffer += &format!("    signal input key{}[keyLen{}];\n", i + 1, i + 1)
                }
                Key::Num(_) => (),
            }
        }
    }

    /*
    component rHasher = PoseidonModular(dataLen + keyLen1 + keyLen3);
    for (var i = 0; i < keyLen1; i++) {
        rHasher.in[i] <== key1[i];
    }
    for (var i = 0; i < keyLen3; i++) {
        rHasher.in[keyLen1 + i] <== key3[i];
    }
    for (var i = 0; i < dataLen; i++) {
        rHasher.in[i + keyLen1 + keyLen3] <== data[i];
    }
    signal r <== rHasher.out;
     */
    {
        circuit_buffer += "\n    // r must be secret, so either has to be derived from hash in the circuit or off the circuit\n    component rHasher = PoseidonModular(DATA_BYTES + ";
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => circuit_buffer += &format!(" keyLen{} +", i + 1),
                Key::Num(_) => (),
            }
        }
        circuit_buffer.pop();
        circuit_buffer.pop();
        circuit_buffer += ");\n";

        let mut key_len_counter_str = String::from_str("i")?;
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => {
                    circuit_buffer += &format!("    for (var i = 0 ; i < keyLen{} ; i++) {{\n        rHasher.in[{}] <== key{}[i];\n    }}\n", i+1, key_len_counter_str, i+1);
                    key_len_counter_str += &format!(" + keyLen{}", i + 1);
                }
                Key::Num(_) => (),
            }
        }

        circuit_buffer += &format!("    for (var i = 0 ; i < DATA_BYTES ; i++) {{\n        rHasher.in[{}] <== data[i];\n    }}\n", key_len_counter_str);
    }

    circuit_buffer += r#"    signal r <== rHasher.out;

    signal output value_starting_index[DATA_BYTES];

    signal mask[DATA_BYTES];
    // mask[0] <== 0;

    var logDataLen = log2Ceil(DATA_BYTES);

    component State[DATA_BYTES];
    State[0] = StateUpdate(MAX_STACK_HEIGHT);
    State[0].byte           <== data[0];
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        State[0].stack[i]   <== [0,0];
    }
    State[0].parsing_string <== 0;
    State[0].parsing_number <== 0;

    signal parsing_key[DATA_BYTES];
    signal parsing_value[DATA_BYTES];
"#;

    /* // signals for parsing string key and array index
    signal parsing_key[DATA_BYTES];
    signal parsing_value[DATA_BYTES];
    signal parsing_object1_value[DATA_BYTES];
    signal parsing_array2[DATA_BYTES];
    signal is_key1_match[DATA_BYTES];
    signal is_key1_match_for_value[DATA_BYTES];
    is_key1_match_for_value[0] <== 0;
    signal is_next_pair_at_depth1[DATA_BYTES];
     */
    {
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => {
                    circuit_buffer +=
                        &format!("    signal parsing_object{}_value[DATA_BYTES];\n", i + 1)
                }
                Key::Num(_) => {
                    circuit_buffer += &format!("    signal parsing_array{}[DATA_BYTES];\n", i + 1)
                }
            }
        }

        for (i, key) in data.keys.iter().enumerate() {
            match key {
            Key::String(_) => circuit_buffer += &format!("    signal is_key{}_match[DATA_BYTES];\n    signal is_key{}_match_for_value[DATA_BYTES];\n    is_key{}_match_for_value[0] <== 0;\n    signal is_next_pair_at_depth{}[DATA_BYTES];\n", i+1, i+1, i+1, i+1),
            Key::Num(_) => (),
        }
        }
    }

    // debugging
    circuit_buffer += r#"
    signal is_value_match[DATA_BYTES];
    is_value_match[0] <== 0;
    signal value_mask[DATA_BYTES];

    for(var data_idx = 1; data_idx < DATA_BYTES; data_idx++) {"#;

    if debug {
        circuit_buffer += r#"
        // Debugging
        for(var i = 0; i<MAX_STACK_HEIGHT; i++) {
            log("State[", data_idx-1, "].stack[", i,"]    ", "= [",State[data_idx-1].next_stack[i][0], "][", State[data_idx-1].next_stack[i][1],"]" );
        }
        log("State[", data_idx-1, "].byte", "= ", data[data_idx-1]);
        log("State[", data_idx-1, "].parsing_string", "= ", State[data_idx-1].next_parsing_string);
        log("State[", data_idx-1, "].parsing_number", "= ", State[data_idx-1].next_parsing_number);
"#;
    }

    circuit_buffer += r#"
        State[data_idx]                  = StateUpdate(MAX_STACK_HEIGHT);
        State[data_idx].byte           <== data[data_idx];
        State[data_idx].stack          <== State[data_idx - 1].next_stack;
        State[data_idx].parsing_string <== State[data_idx - 1].next_parsing_string;
        State[data_idx].parsing_number <== State[data_idx - 1].next_parsing_number;

        // - parsing key
        // - parsing value (different for string/numbers and array)
        // - key match (key 1, key 2)
        // - is next pair
        // - is key match for value
        // - value_mask
        // - mask

        // check if inside key or not
        parsing_key[data_idx-1] <== InsideKey(MAX_STACK_HEIGHT)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);

"#;

    /* Determining wheter parsing correct value and array index
    parsing_object1_value[data_idx-1] <== InsideValueAtDepth(MAX_STACK_HEIGHT, depth1)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
    parsing_array2[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index2, depth2)(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);
     */
    {
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => {
                    circuit_buffer += &format!("        parsing_object{}_value[data_idx-1] <== InsideValueAtDepth(MAX_STACK_HEIGHT, depth{})(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);\n", i+1, i+1);
                }
                Key::Num(_) => {
                    circuit_buffer += &format!("        parsing_array{}[data_idx-1] <== InsideArrayIndexAtDepth(MAX_STACK_HEIGHT, index{}, depth{})(State[data_idx].stack, State[data_idx].parsing_string, State[data_idx].parsing_number);\n", i+1, i+1, i+1);
                }
            }
        }
    }

    // parsing correct value = AND(all individual stack values)
    //     parsing_value[data_idx-1] <== MultiAND(4)([parsing_object1_value[data_idx-1], parsing_array2[data_idx-1], parsing_object3_value[data_idx-1], parsing_array4[data_idx-1]]);
    {
        circuit_buffer += &format!(
        "        // parsing correct value = AND(all individual stack values)\n        parsing_value[data_idx-1] <== MultiAND({})([",
        data.keys.len()
    );

        for (i, key) in data.keys.iter().take(data.keys.len() - 1).enumerate() {
            match key {
                Key::String(_) => {
                    circuit_buffer += &format!("parsing_object{}_value[data_idx-1], ", i + 1)
                }
                Key::Num(_) => circuit_buffer += &format!("parsing_array{}[data_idx-1], ", i + 1),
            }
        }
        match data.keys[data.keys.len() - 1] {
            Key::String(_) => {
                circuit_buffer +=
                    &format!("parsing_object{}_value[data_idx-1]]);\n", data.keys.len())
            }
            Key::Num(_) => {
                circuit_buffer += &format!("parsing_array{}[data_idx-1]]);\n", data.keys.len())
            }
        }

        // optional debug logs
        if debug {
            circuit_buffer += "        // log(\"parsing value:\", ";
            for (i, key) in data.keys.iter().enumerate() {
                match key {
                    Key::String(_) => {
                        circuit_buffer += &format!("parsing_object{}_value[data_idx-1], ", i + 1)
                    }
                    Key::Num(_) => {
                        circuit_buffer += &format!("parsing_array{}[data_idx-1], ", i + 1)
                    }
                }
            }
            circuit_buffer += "parsing_value[data_idx-1]);\n\n";
        }
    }

    let mut num_objects = 0;

    /*
    to get correct value, check:
    - key matches at current index and depth of key is as specified
    - whether next KV pair starts
    - whether key matched for a value (propogate key match until new KV pair of lower depth starts)
    is_key1_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen1, depth1)(data, key1, r, data_idx-1, parsing_key[data_idx-1], State[data_idx].stack);
    is_next_pair_at_depth1[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth1)(State[data_idx].stack, data[data_idx-1]);
    is_key1_match_for_value[data_idx] <== Mux1()([is_key1_match_for_value[data_idx-1] * (1-is_next_pair_at_depth1[data_idx-1]), is_key1_match[data_idx-1] * (1-is_next_pair_at_depth1[data_idx-1])], is_key1_match[data_idx-1]);
    */
    {
        circuit_buffer += r#"
        // to get correct value, check:
        // - key matches at current index and depth of key is as specified
        // - whether next KV pair starts
        // - whether key matched for a value (propogate key match until new KV pair of lower depth starts)
"#;

        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => {
                    num_objects += 1;
                    circuit_buffer += &format!("        is_key{}_match[data_idx-1] <== KeyMatchAtDepth(DATA_BYTES, MAX_STACK_HEIGHT, keyLen{}, depth{})(data, key{}, r, data_idx-1, parsing_key[data_idx-1], State[data_idx].stack);\n", i+1, i+1, i+1, i+1);
                    circuit_buffer += &format!("        is_next_pair_at_depth{}[data_idx-1] <== NextKVPairAtDepth(MAX_STACK_HEIGHT, depth{})(State[data_idx].stack, data[data_idx-1]);\n", i+1, i+1);
                    circuit_buffer += &format!("        is_key{}_match_for_value[data_idx] <== Mux1()([is_key{}_match_for_value[data_idx-1] * (1-is_next_pair_at_depth{}[data_idx-1]), is_key{}_match[data_idx-1] * (1-is_next_pair_at_depth{}[data_idx-1])], is_key{}_match[data_idx-1]);\n", i+1, i+1, i+1, i+1, i+1, i+1);
                    if debug {
                        circuit_buffer += &format!("        // log(\"is_key{}_match_for_value\", is_key{}_match_for_value[data_idx]);\n\n", i + 1, i + 1);
                    }
                }
                Key::Num(_) => (),
            }
        }
    }

    // is_value_match[data_idx] <== MultiAND(2)([is_key1_match_for_value[data_idx], is_key3_match_for_value[data_idx]]);
    {
        circuit_buffer += &format!(
            "        is_value_match[data_idx] <== MultiAND({})([",
            num_objects
        );
        for (i, key) in data.keys.iter().enumerate() {
            match key {
                Key::String(_) => {
                    circuit_buffer += &format!("is_key{}_match_for_value[data_idx], ", i + 1)
                }
                Key::Num(_) => (),
            }
        }

        // remove last 2 chars `, ` from string buffer
        circuit_buffer.pop();
        circuit_buffer.pop();
        circuit_buffer += "]);\n";
    }

    // debugging and output bytes
    {
        circuit_buffer += r#"
        // mask[i] = data[i] * parsing_value[i] * is_key_match_for_value[i]
        value_mask[data_idx-1] <== data[data_idx-1] * parsing_value[data_idx-1];
        mask[data_idx-1] <== value_mask[data_idx-1] * is_value_match[data_idx];
    }"#;

        // Debugging
        if debug {
            circuit_buffer += r#"
    for(var i = 0; i < MAX_STACK_HEIGHT; i++) {
        log("State[", DATA_BYTES-1, "].stack[", i,"]    ", "= [",State[DATA_BYTES -1].next_stack[i][0], "][", State[DATA_BYTES - 1].next_stack[i][1],"]" );
    }
    log("State[", DATA_BYTES-1, "].parsing_string", "= ", State[DATA_BYTES-1].next_parsing_string);
    log("State[", DATA_BYTES-1, "].parsing_number", "= ", State[DATA_BYTES-1].next_parsing_number);
    log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    "#;
        }

        circuit_buffer += r#"

    signal is_zero_mask[DATA_BYTES];
    signal is_prev_starting_index[DATA_BYTES];
    value_starting_index[0] <== 0;
    is_zero_mask[0] <== IsZero()(mask[0]);
    for (var i=1 ; i<DATA_BYTES-1 ; i++) {
        is_zero_mask[i] <== IsZero()(mask[i]);
        is_prev_starting_index[i] <== IsZero()(value_starting_index[i-1]);
        value_starting_index[i] <== value_starting_index[i-1] + i * (1-is_zero_mask[i]) * is_prev_starting_index[i];
    }
"#;

        // template ends
        circuit_buffer += "}\n";
    }

    match data.value_type {
        ValueType::String => extract_string(data, &mut circuit_buffer, debug),
        ValueType::Number => extract_number(data, &mut circuit_buffer, debug),
    }

    // write circuits to file
    let mut file_path = std::env::current_dir()?;
    file_path.push("circuits");
    file_path.push("main");

    // create dir if doesn't exist
    create_dir_all(&file_path)?;

    file_path.push(format!("{}.circom", output_filename));

    fs::write(&file_path, circuit_buffer)?;

    println!("Code generated at: {}", file_path.display());

    Ok(())
}

fn build_circuit_config(
    args: &ExtractorArgs,
    lockfile: &JsonLockfile,
) -> Result<CircomkitCircuitsInput, Box<dyn std::error::Error>> {
    let input = fs::read(args.input_file.clone())?;

    let circuit_template_name = match lockfile.value_type {
        ValueType::String => String::from("ExtractStringValue"),
        ValueType::Number => String::from("ExtractNumValue"),
    };

    let mut max_stack_height = 1;
    let mut curr_stack_height = 1;
    let mut inside_string: bool = false;

    for (i, char) in input[1..].iter().enumerate() {
        match char {
            b'"' if input[i - 1] != b'\\' => inside_string = !inside_string,
            b'{' | b'[' if !inside_string => {
                curr_stack_height += 1;
                max_stack_height = max_by(max_stack_height, curr_stack_height, |x, y| x.cmp(y));
            }
            b'}' | b']' if !inside_string => curr_stack_height -= 1,
            _ => {}
        }
    }

    let mut params = vec![input.len(), max_stack_height];

    let mut current_value: Value = serde_json::from_slice(&input)?;
    for (i, key) in lockfile.keys.iter().enumerate() {
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
                    params.push(index.to_string().as_bytes().len());
                    current_value = value.to_owned();
                } else {
                    return Err(String::from("provided index not present in input JSON").into());
                }
            }
        }
        params.push(i);
    }

    let value_bytes = match lockfile.value_type {
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

    Ok(CircomkitCircuitsInput {
        file: format!("main/{}", args.output_filename),
        template: circuit_template_name,
        params,
    })
}

pub fn json_circuit(args: ExtractorArgs) -> Result<(), Box<dyn std::error::Error>> {
    let lockfile: JsonLockfile = serde_json::from_slice(&std::fs::read(&args.lockfile)?)?;

    build_json_circuit(&lockfile, &args.output_filename, args.debug)?;

    let circomkit_circuit_input = build_circuit_config(&args, &lockfile)?;

    write_circuit_config(args.circuit_name, &circomkit_circuit_input)?;

    Ok(())
}
