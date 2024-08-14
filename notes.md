# Notes

## TODOs
### JSON Types
- [x] Object
- [x] String
- [x] Array
- [x] Number
- [ ] Boolean
- [ ] Null

Parsing null and bool need to do some kind of look ahead parsing. To handle numbers properly we also probably need that actually since we need to look ahead to where we get white space.
Need to look ahead for `true` and `false` for example to ensure we get a full match, or we fail or something. Lookaehad might be overkill, but yeah.

#### Numbers
Numbers can have `e` and decimal `.` in them. Riperoni.

### string escape
shouldn't be too hard, just add one more state variable `escaping` that is only enabled when parsing a string and can only be toggled -- next state will always have to set back to 0.

This could also allow for parsing unicode

## Expected Output
> This is old at this point, but we should update it.
```
Notes: for `test.json`
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 POINTER | Read In: | STATE
-------------------------------------------------
State[1] | {        | PARSING TO KEY
-------------------------------------------------
State[7] | "        | INSIDE KEY
-------------------------------------------------
State[12]| "        | NOT INSIDE KEY
-------------------------------------------------
State[13]| :        | PARSING TO VALUE
-------------------------------------------------
State[15]| "        | INSIDE VALUE
-------------------------------------------------
State[19]| "        | NOT INSIDE VALUE
-------------------------------------------------
State[20]| "        | COMPLETE WITH KV PARSING
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
State[20].next_tree_depth == 0 | VALID JSON
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```