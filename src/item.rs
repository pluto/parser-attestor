#[derive(Clone, Copy, Debug)]
pub struct Item<'a, T> {
    pub label: &'a str,
    inner: T,
}

impl<'a> Item<'a, ()> {
    pub fn create(label: &'a str) -> Self {
        Item { label, inner: () }
    }
}

impl<'a, T: Copy> Item<'a, T> {
    pub fn inner(&self) -> T {
        self.inner
    }

    pub fn append(self, label: &'a str) -> Item<'a, Item<T>> {
        Item { label, inner: self }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_nested_item() {
        let item = Item::create("data")
            .append("profile")
            .append("identity")
            .append("balance")
            .append("userBalance")
            .append("value");
        println!("{item:?}");
    }
}
