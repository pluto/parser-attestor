use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::{error::Error, path::PathBuf};

pub mod codegen;
pub mod http;
pub mod json;
pub mod witness;

#[derive(Parser, Debug)]
#[command(name = "pabuild")]
pub struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    ParserWitness(ParserWitnessArgs),
    ExtractorWitness(ExtractorWitnessArgs),
    Json(ExtractorArgs),
    Http(ExtractorArgs),
}

#[derive(Parser, Debug)]
pub struct ParserWitnessArgs {
    #[arg(value_enum)]
    subcommand: WitnessType,

    /// Path to the JSON file
    #[arg(long)]
    input_file: PathBuf,

    /// Name of the circuit (to be used in circomkit config)
    #[arg(long)]
    circuit_name: String,
}

#[derive(Parser, Debug)]
pub struct ExtractorWitnessArgs {
    #[arg(value_enum)]
    subcommand: WitnessType,

    /// Name of the circuit (to be used in circomkit config)
    #[arg(long)]
    circuit_name: String,

    /// Path to the JSON file
    #[arg(long)]
    input_file: PathBuf,

    /// Path to the lockfile
    #[arg(long)]
    lockfile: PathBuf,
}

#[derive(clap::ValueEnum, Clone, Debug)]
pub enum WitnessType {
    Json,
    Http,
}

#[derive(Parser, Debug)]
pub struct ExtractorArgs {
    /// Name of the circuit (to be used in circomkit config)
    #[arg(long)]
    circuit_name: String,

    /// Path to the JSON file
    #[arg(long)]
    input_file: PathBuf,

    /// Path to the lockfile
    #[arg(long)]
    lockfile: PathBuf,

    /// Output circuit file name (located in circuits/main/)
    #[arg(long, short, default_value = "extractor")]
    output_filename: String,

    /// Optional circuit debug logs
    #[arg(long, short, action = clap::ArgAction::SetTrue)]
    debug: bool,
}

pub fn main() -> Result<(), Box<dyn Error>> {
    match Args::parse().command {
        Command::ParserWitness(args) => witness::parser_witness(args),
        Command::Json(args) => json::json_circuit(args),
        Command::Http(args) => http::http_circuit(args),
        Command::ExtractorWitness(args) => witness::extractor_witness(args),
    }
}
