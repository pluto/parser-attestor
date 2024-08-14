# Notes

## TODOs
### JSON Types
- [x] Object
- [x] String
- [ ] Array (PARTIALLY COMPLETED, TODO: Need to parse internally)
- [x] Number
- [ ] Boolean
- [ ] Null

### string escape
shouldn't be too hard, just add one more state variable `escaping` that is only enabled when parsing a string and can only be toggled -- next state will always have to set back to 0.

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