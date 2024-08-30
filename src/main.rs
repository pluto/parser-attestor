use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::{error::Error, path::PathBuf};

pub mod extractor;
pub mod witness;

#[derive(Parser, Debug)]
#[command(name = "wpbuild")]
pub struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    Witness(WitnessArgs),
    Extractor(ExtractorArgs),
}

#[derive(Parser, Debug)]
pub struct WitnessArgs {
    #[command(subcommand)]
    subcommand: WitnessSubcommand,

    /// Path to the JSON file
    #[arg(global = true, long)]
    input_file: PathBuf,

    /// Output directory (will be created if it doesn't exist)
    #[arg(global = true, long, default_value = ".")]
    output_dir: PathBuf,

    /// Output filename (will be created if it doesn't exist)
    #[arg(global = true, long, default_value = "output.json")]
    output_filename: String,
}

#[derive(Subcommand, Debug)]
pub enum WitnessSubcommand {
    Json,
    Http,
}

#[derive(Parser, Debug)]
pub struct ExtractorArgs {
    /// Path to the JSON file
    #[arg(long)]
    template: PathBuf,

    /// Output circuit file name
    #[arg(long, default_value = "extractor")]
    output_filename: String,
}

#[derive(Debug, Deserialize)]
enum ValueType {
    #[serde(rename = "string")]
    String,
    #[serde(rename = "number")]
    Number,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
enum Key {
    String(String),
    Num(i64),
}

#[derive(Debug, Deserialize)]
struct Data {
    keys: Vec<Key>,
    value_type: ValueType,
}

pub fn main() -> Result<(), Box<dyn Error>> {
    match Args::parse().command {
        Command::Extractor(args) => extractor::extractor(args),
        Command::Witness(args) => witness::witness(args),
    }
}
