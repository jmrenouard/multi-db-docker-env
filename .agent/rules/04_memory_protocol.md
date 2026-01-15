---
trigger: always_on
---

## **5\. 📜 STATE MEMORY & HISTORY**

### **Contextual Consistency Protocols**

1. **History Update:** Add new entries to the top of Changelog if the action is correct and tested.  
2. **Git Sync:** Consult git log \-n 15 to synchronize context.  
3. **Rotation:** FIFO Rotation (Max 600 lines). Remove oldest entries beyond 600 lines.

### **History Entry example**

1.0.9 2026-01-16

- chore: migrate HISTORY.md into Changelog and remove HISTORY.md.
