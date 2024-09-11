use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::{error::Error, path::PathBuf};

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
    Json(JsonArgs),
    Http(HttpArgs),
}

#[derive(Parser, Debug)]
pub struct ParserWitnessArgs {
    #[arg(global = true, value_enum)]
    subcommand: WitnessSubcommand,

    /// Path to the JSON file
    #[arg(global = true, long)]
    input_file: PathBuf,

    /// Output directory (will be created if it doesn't exist)
    #[arg(global = true, long, default_value = ".")]
    output_dir: PathBuf,

    /// Output filename (will be created if it doesn't exist)
    #[arg(global = true, long, default_value = "input.json")]
    output_filename: String,
}

#[derive(Parser, Debug)]
pub struct ExtractorWitnessArgs {
    #[arg(global = true, value_enum)]
    subcommand: WitnessSubcommand,

    /// Path to the JSON file
    #[arg(global = true, long)]
    input_file: PathBuf,

    /// Path to the lockfile
    #[arg(global = true, long)]
    lockfile: PathBuf,

    /// Output directory (will be created if it doesn't exist)
    #[arg(global = true, long, default_value = ".")]
    output_dir: PathBuf,

    /// Output filename (will be created if it doesn't exist)
    #[arg(global = true, long, default_value = "input.json")]
    output_filename: String,
}

#[derive(clap::ValueEnum, Clone, Debug)]
pub enum WitnessSubcommand {
    Json,
    Http,
}

#[derive(Parser, Debug)]
pub struct JsonArgs {
    /// Path to the JSON file selective-disclosure template
    #[arg(long, short)]
    template: PathBuf,

    /// Output circuit file name
    #[arg(long, short, default_value = "extractor")]
    output_filename: String,

    /// Optional circuit debug logs
    #[arg(long, short, action = clap::ArgAction::SetTrue)]
    debug: bool,
}

#[derive(Parser, Debug)]
pub struct HttpArgs {
    /// Path to the JSON file
    #[arg(long)]
    lockfile: PathBuf,

    /// Output circuit file name
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
