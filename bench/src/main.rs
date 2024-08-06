// Modified from <https://github.com/noir-lang/zk_bench>
mod circom;
mod noir;
mod suite;
fn main() {
    println!("Starting benchmark!");
    suite::run().unwrap();
}
