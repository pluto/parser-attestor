use string_search::{StringBody, SubString, StringBody1024, SubString32, StringBody4096, SubString64};

fn main(haystack_text: [u8; 787], needle_text: [u8; 10]) -> pub (bool, u32) {
    let mut haystack: StringBody1024 = StringBody::new(haystack_text, haystack_text.len());
    let mut needle: SubString32 = SubString::new(needle_text, needle_text.len());
    haystack.substring_match(needle)
}

// fn main(haystack_text: [u8; 3011], needle_text: [u8; 35]) -> pub (bool, u32) {
//     let mut haystack: StringBody4096 = StringBody::new(haystack_text, haystack_text.len());
//     let mut needle: SubString64 = SubString::new(needle_text, needle_text.len());
//     haystack.substring_match(needle)
// }
