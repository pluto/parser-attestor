use std::{
    env,
    path::{Path, PathBuf},
};

use tempfile::{tempdir, TempDir};

use crate::suite::Language;

const CIRCOM_BINARY: &str = "circom";
// const SNARKJS_BINARY: &str = "yarn snarkjs";

pub struct Circom {
    temp_dir: Option<TempDir>,
    circuit_name: String,
}

impl Language for Circom {
    fn init(&mut self, _entry_point: &Path) -> Result<(), String> {
        self.new_temp_dir();
        Ok(())
    }

    /// circom circuit.circom --r1cs --wasm --sym
    fn compile(&self, entry_point: &Path) -> Result<PathBuf, String> {
        let temp_directory_path = self.get_temp_dir().path();

        let mut command = std::process::Command::new(CIRCOM_BINARY);
        let output = command
            .arg(entry_point.join(format!("{}.circom", self.circuit_name)))
            .arg("--r1cs")
            .arg("--wasm")
            .arg("--sym")
            .arg("-o")
            .arg(temp_directory_path)
            .output();
        match output {
            Ok(output) => {
                if output.status.success() {
                    let str = String::from_utf8_lossy(&output.stdout).to_string();
                    if !str.contains("Everything went okay") {
                        return Err(format!("Error running circom: {}", str));
                    }
                } else {
                    let msg = String::from_utf8_lossy(&output.stderr).to_string(); //string_from_stderr...
                    return Err(msg);
                }
            }
            Err(msg) => return Err(format!("Error running circom: {}", msg)),
        }
        Ok(temp_directory_path.join(format!("{}.r1cs", self.circuit_name)))
    }

    /// snarkjs r1cs info mon_fichier.r1cs
    fn info(&self, entry_point: &Path) -> Result<(Option<u64>, u64), String> {
        let mut command = std::process::Command::new("snarkjs");
        let output = command
            .arg("r1cs")
            .arg("info")
            .arg(entry_point)
            .output()
            .map_err(|c| format!("Error running snarkjs: {}", c))?;

        if output.status.success() {
            let str = String::from_utf8_lossy(&output.stdout).to_string();
            for line in str.lines() {
                if let Some(pos) = line.find("Constraints: ") {
                    let result = line[pos + 13..]
                        .parse::<u32>()
                        .map_err(|c| format!("Error running snarkjs: {}", c))?;
                    return Ok((None, result as u64));
                }
            }
            Err(format!(
                "Error, could not get the number of constraints: {}",
                str
            ))
        } else {
            let msg = String::from_utf8_lossy(&output.stderr).to_string(); //string_from_stderr...
            Err(format!("Error running snarkjs: {}", msg))
        }
    }

    /// snarkjs groth16 setup mon.r1cs pot15_final.ptau ma.zkey
    fn setup(&self, entry_point: &Path) -> Result<PathBuf, String> {
        let tau = powers_of_tau().unwrap();
        let temp_directory_path = self.get_temp_dir().path();
        let key_path = temp_directory_path.join("circom.key");
        let mut command = std::process::Command::new("snarkjs");
        command
            .arg("groth16")
            .arg("setup")
            .arg(entry_point)
            .arg(tau)
            .arg(&key_path)
            .output()
            .map_err(|c| format!("Error running snarkjs: {}", c))?;

        let key_path = assert_file(key_path)?;
        Ok(key_path)
    }

    /// node generate_witness.js multiplier2.wasm input.json witness.wtns
    fn execute(&self, entry_point: &Path) -> Result<PathBuf, String> {
        let witness_js = self
            .get_temp_dir()
            .path()
            .join(format!("{}_js", self.circuit_name))
            .join("generate_witness.js");
        let witness_js = assert_file(witness_js)?;
        let wasm_file = self
            .get_temp_dir()
            .path()
            .join(format!("{}_js", self.circuit_name))
            .join(format!("{}.wasm", self.circuit_name));
        let wasm_file = assert_file(wasm_file)?;

        let temp_directory = self.get_temp_dir().path();
        let witnesses = temp_directory.join("witness.wtns");
        let inputs = entry_point.join("witness.json");

        let inputs = assert_file(inputs)?;

        let mut command = std::process::Command::new("node");
        let output = command
            .arg(witness_js)
            .arg(wasm_file)
            .arg(inputs) //TODO on devrait l'avoir celui la
            .arg(&witnesses)
            .output()
            .map_err(|c| format!("Error running snarkjs: {}", c))?;

        if output.status.success() {
            let _str = String::from_utf8_lossy(&output.stdout).to_string();
            Ok(witnesses)
        } else {
            let msg = String::from_utf8_lossy(&output.stderr).to_string(); //string_from_stderr...
            Err(format!("Error running snarkjs: {}", msg))
        }
    }

    /// snarkjs groth16 prove ma.zkey witness.wtns proof.json public.json
    fn prove(&self, key: &Path, witness: &Path) -> Result<PathBuf, String> {
        let temp_directory = tempdir().expect("could not create a temporary directory");
        let temp_directory_path = temp_directory.path();
        let proof_path = temp_directory_path.join("proof.json");
        let public = temp_directory_path.join("public.json");

        let mut command = std::process::Command::new("snarkjs");
        let output = command
            // .arg("snarkjs")
            .arg("groth16")
            .arg("prove")
            .arg(key)
            .arg(witness)
            .arg(&proof_path)
            .arg(public)
            .output()
            .map_err(|c| format!("Error running snarkjs: {}", c))?;

        if output.status.success() {
            let _str = String::from_utf8_lossy(&output.stdout).to_string();
            Ok(proof_path)
        } else {
            let msg = String::from_utf8_lossy(&output.stderr).to_string(); //string_from_stderr...
            Err(format!("Error running snarkjs: {}", msg))
        }
    }

    fn done(&mut self) {
        self.close_temp_dir();
    }
}

impl Circom {
    fn new_temp_dir(&mut self) {
        self.temp_dir = Some(tempdir().expect("could not create a temporary directory"));
    }

    fn close_temp_dir(&mut self) {
        self.temp_dir = None;
    }

    fn get_temp_dir(&self) -> &TempDir {
        self.temp_dir.as_ref().unwrap()
    }

    pub fn new(circuit_name: String) -> Circom {
        Circom {
            temp_dir: None,
            circuit_name,
        }
    }
}

pub fn powers_of_tau() -> Result<PathBuf, String> {
    let path = env::current_dir().map_err(|c| format!("Error: {}", c))?;
    assert_file(
        path.join("../circuit")
            .join("powersOfTau28_hez_final_19.ptau"),
    )
}

fn assert_file(file: PathBuf) -> Result<PathBuf, String> {
    if file.is_file() {
        Ok(file)
    } else {
        Err("no file".into())
    }
}
