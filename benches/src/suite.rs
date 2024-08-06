use std::env;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use crate::circom::Circom;
use crate::noir;

pub trait Language {
    fn init(&mut self, entry_point: &Path) -> Result<(), String>;
    fn compile(&self, entry_point: &Path) -> Result<PathBuf, String>;
    fn info(&self, entry_point: &Path) -> Result<(Option<u64>, u64), String>;
    fn setup(&self, entry_point: &Path) -> Result<PathBuf, String>;
    fn execute(&self, entry_point: &Path) -> Result<PathBuf, String>;
    fn prove(&self, key: &Path, witness: &Path) -> Result<PathBuf, String>;
    fn done(&mut self);
}

pub fn run() -> Result<(), String> {
    let circom_path = env::current_dir()
        .map_err(|c| format!("Error: {}", c))?
        .join("../circuit");
    let noir_path = env::current_dir()
        .map_err(|c| format!("Error: {}", c))?
        .join("noir_string_search");

    let mut circom = Circom::new();
    let mut noir = noir::Noir {};
    // let tests = fs::read_dir(main_path)
    //     .unwrap()
    //     .flatten()
    //     .filter(|c| c.path().is_dir());
    // for test in tests {
    //let test_name = test.file_name();
    let circom_bench = benchme(circom_path, &mut circom)?;
    println!(
        "Testing {} with circom:
        {} constraints
        setup generated in {}ms
        compiled in {}ms
        execution in {}ms
        prove in {}ms",
        circom_bench.name,
        circom_bench.constraints,
        circom_bench.setup_duration.as_millis(),
        circom_bench.compilation_duration.as_millis(),
        circom_bench.exec_duration.as_millis(),
        circom_bench.prove_duration.as_millis()
    );

    let noir_bench = benchme(noir_path, &mut noir)?;
    println!(
        "Testing {} with Noir:
        {} constraints ({} ACIR opcodes)
        setup generated in {}ms
        compiled in {}ms
        execution in {}ms
        prove in {}ms",
        noir_bench.name,
        noir_bench.constraints,
        noir_bench.opcodes.unwrap(),
        noir_bench.setup_duration.as_millis(),
        noir_bench.compilation_duration.as_millis(),
        noir_bench.exec_duration.as_millis(),
        noir_bench.prove_duration.as_millis()
    );
    // }
    Ok(())
}

pub(super) struct BenchResult {
    name: String,
    opcodes: Option<u64>,
    constraints: u64,
    setup_duration: Duration,
    compilation_duration: Duration,
    exec_duration: Duration,
    prove_duration: Duration,
}

pub fn benchme<T>(circuit_path: PathBuf, lang: &mut T) -> Result<BenchResult, String>
where
    T: Language,
{
    lang.init(&circuit_path)?;

    //1. compile:
    let start = Instant::now();
    let r1cs_file = lang.compile(&circuit_path)?;
    let compilation_duration = start.elapsed();

    //2. info
    let (opcodes, constraints) = lang.info(&r1cs_file)?;

    //3. setup
    let start = Instant::now();
    let key = lang.setup(&r1cs_file)?;
    let setup_duration = start.elapsed();

    //4. witness generation
    let start = Instant::now();
    let witness_path = lang.execute(&circuit_path)?;
    let exec_duration = start.elapsed();

    //5. prove
    let start = Instant::now();
    lang.prove(&key, &witness_path)?;
    let prove_duration = start.elapsed();
    let test_name = circuit_path.file_name().unwrap().to_str().unwrap();

    let result = BenchResult {
        name: test_name.to_owned(),
        opcodes,
        constraints,
        setup_duration,
        compilation_duration,
        exec_duration,
        prove_duration,
    };

    lang.done();
    Ok(result)
}
