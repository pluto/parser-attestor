use clap::{Parser, Subcommand};
use std::{error::Error, path::PathBuf};

pub mod codegen;
pub mod witness;

#[derive(Parser, Debug)]
#[command(name = "pabuild")]
pub struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    #[command(subcommand)]
    Witness(WitnessType),
    Codegen(ExtractorArgs),
}

#[derive(clap::ValueEnum, Clone, Debug)]
pub enum FileType {
    Json,
    Http,
}

#[derive(Debug, Parser)]
pub enum WitnessType {
    Parser(ParserWitnessArgs),
    Extractor(ExtractorWitnessArgs),
}

#[derive(Parser, Debug)]
pub struct ParserWitnessArgs {
    #[arg(value_enum)]
    subcommand: FileType,

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
    subcommand: FileType,

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

#[derive(Parser, Debug)]
pub struct ExtractorArgs {
    #[arg(value_enum)]
    subcommand: FileType,

    /// Name of the circuit (to be used in circomkit config)
    #[arg(long)]
    circuit_name: String,

    /// Path to the JSON/HTTP file
    #[arg(long)]
    input_file: PathBuf,

    /// Path to the lockfile
    #[arg(long)]
    lockfile: PathBuf,

    /// Optional circuit debug logs
    #[arg(long, short, action = clap::ArgAction::SetTrue)]
    debug: bool,
}

pub fn main() -> Result<(), Box<dyn Error>> {
    match Args::parse().command {
        Command::Witness(witness_type) => match witness_type {
            WitnessType::Parser(args) => witness::parser_witness(args),
            WitnessType::Extractor(args) => witness::extractor_witness(args),
        },
        Command::Codegen(args) => match args.subcommand {
            FileType::Http => codegen::http::http_circuit(args),
            FileType::Json => codegen::json::json_circuit(args),
        },
    }
}
