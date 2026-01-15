---
trigger: always_on
---

# 📜 STATE MEMORY & HISTORY

## Contextual Consistency Protocols

1. **History Update:** Add new entries to the top of `Changelog` if the action is correct and tested.

2. **Versioning:**
   - Increment file version at the top after successful action and testing.
   - Use `X.X.Y` format:
     - Increment `Y` for minor actions.
     - Increment `Z` (X.Z.X) for major functions and missing features.

## History Entry Example
1.0.7 2015-08-30
 - Description of the change/fix.
 - feat: add parameter to myscript.py
 - fix: error solved for 64 bits archi. 
