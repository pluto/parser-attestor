pub const EXAMPLE_JSON: &[u8] = include_bytes!("../example.json");
pub const VENMO_JSON: &[u8] = include_bytes!("../venmo_response.json");

pub mod item;

pub struct Machine<'a> {
    pub keys: Vec<&'a [u8]>,
    depth: usize,
    pointer: usize,
}

#[derive(Debug)]
pub enum Instruction {
    IncreaseDepth(usize),
    DecreaseDepth(usize),
    EOF,
}

impl<'a> Machine<'a> {
    pub fn new(keys: Vec<&'a [u8]>) -> Self {
        Machine {
            keys,
            depth: 0,
            pointer: 0,
        }
    }

    pub fn extract(&mut self, data_bytes: &'a [u8]) -> Option<&'a [u8]> {
        // Make sure that there is more data in the JSON than what we have expressed in all of our keys else this makes no sense at all.
        assert!(data_bytes.len() > self.keys.iter().map(|k| k.len()).sum());
        // Make sure the JSON begins with an opening bracket
        assert_eq!(data_bytes[0] ^ b"{"[0], 0);

        while self.depth < self.keys.len() {
            match get_key(self.keys[self.depth], &data_bytes[self.pointer..]) {
                Instruction::EOF => return None,
                _inst @ Instruction::DecreaseDepth(offset) => {
                    // dbg!(inst);
                    self.depth -= 1;
                    self.pointer += offset;
                    // dbg!(String::from_utf8_lossy(&[data_bytes[self.pointer]]));
                }
                _inst @ Instruction::IncreaseDepth(offset) => {
                    // dbg!(inst);
                    self.depth += 1;
                    self.pointer += offset;
                    // dbg!(String::from_utf8_lossy(&[data_bytes[self.pointer]]));
                }
            }
        }

        // Get the value as a raw str at this location in the JSON and offset by one to bypass a `:`
        let value_start = self.pointer + 1;
        let mut value_length = 0;
        // Grab the value up to the next delimiter doken (TODO: if a `,` or `}` is present in a string, we are doomed, so we need to track these objects better!)
        while (data_bytes[value_start + value_length] != b"}"[0])
            & (data_bytes[value_start + value_length] != b","[0])
        {
            value_length += 1;
        }
        Some(&data_bytes[value_start..value_start + value_length])
    }
}

fn get_key(key: &[u8], data_bytes: &[u8]) -> Instruction {
    let key_length = key.len();

    // dbg!(String::from_utf8_lossy(key));

    'outer: for i in 0..(data_bytes.len() - key_length) {
        #[allow(clippy::needless_range_loop)]
        for j in 0..key_length {
            // dbg!(String::from_utf8_lossy(&[data_bytes[i..i + key_length][j]]));
            if data_bytes[i..i + key_length][j] == b"}"[0] {
                // Hit an end brace "}" so we need to return the current pointer as an offset and decrease depth
                return Instruction::DecreaseDepth(i + j);
            }
            if key[j] ^ data_bytes[i..i + key_length][j] != 0 {
                continue 'outer;
            }
        }
        // If we hit here then we must have fully matched a key so we return the current pointer as an offset
        return Instruction::IncreaseDepth(i + key_length);
    }
    // If we hit here, we must have hit EOF (which is actually an error?)
    Instruction::EOF
}

#[cfg(test)]
mod tests {

    use super::*;

    #[test]
    fn get_value_venmo() {
        let keys = vec![
            b"\"data\"".as_slice(),
            b"\"profile\"".as_slice(),
            b"\"identity\"".as_slice(),
            b"\"balance\"".as_slice(),
            b"\"userBalance\"".as_slice(),
            b"\"value\"".as_slice(),
        ];
        let mut machine = Machine::new(keys);
        let value = String::from_utf8_lossy(machine.extract(VENMO_JSON).unwrap());
        assert_eq!(value, " 523.69\n                    ")
    }

    #[test]
    fn get_value_example() {
        let keys = vec![
            b"\"glossary\"".as_slice(),
            b"\"GlossDiv\"".as_slice(),
            b"\"title\"".as_slice(),
        ];
        let mut machine = Machine::new(keys);
        let value = String::from_utf8_lossy(machine.extract(EXAMPLE_JSON).unwrap());
        assert_eq!(value, " \"S\"")
    }
}
