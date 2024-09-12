use std::{collections::HashMap, env};

use serde::{Deserialize, Serialize};

pub mod http;
pub mod json;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CircomkitCircuitsInput {
    pub file: String,
    pub template: String,
    pub params: Vec<usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CircomkitCircuits(HashMap<String, CircomkitCircuitsInput>);

pub fn write_circuit_config(
    name: String,
    circomkit_input: &CircomkitCircuitsInput,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut circomkit_circuits_config = env::current_dir()?;
    circomkit_circuits_config.push("circuits.json");

    let _ = std::fs::File::create_new(circomkit_circuits_config.clone());

    let mut circomkit_circuits: CircomkitCircuits =
        serde_json::from_slice(&std::fs::read(circomkit_circuits_config.clone())?)?;

    if let Some(circuits_inputs) = circomkit_circuits.0.get_mut(&name) {
        *circuits_inputs = circomkit_input.clone();
    } else {
        let _ = circomkit_circuits
            .0
            .insert(name.clone(), circomkit_input.clone());
    }

    std::fs::write(
        circomkit_circuits_config.clone(),
        serde_json::to_string_pretty(&circomkit_circuits)?,
    )?;

    println!("config updated: {}", circomkit_circuits_config.display());

    Ok(())
}
