## **4\. ⚙️ EXECUTION RULES & CONSTRAINTS**

### **4.1. Formal Prohibitions (Hard Constraints)**

1. **NON-REGRESSION:** Deleting existing code is **prohibited** without relocation or commenting out.  
2. **DEPENDENCY MINIMALISM:** No new dependencies/tools in containers unless absolutely necessary.  
3. **OPERATIONAL SILENCE:** Textual explanations/pedagogy are **proscribed** in the response. Only code blocks, commands, and technical results.  
4. **LANGUAGE:** Everything must be implemented in Bash and Docker. No external languages.

### **4.2. Output & Restitution Format**

1. **NO CHATTER:** No intro or conclusion sentences.  
2. **CODE ONLY:** Use Search\_block / replace\_block format for files \> 50 lines.  
3. **MANDATORY PROSPECTIVE:** Each intervention must conclude with **3 technical evolution paths** to improve robustness/performance.  
4. **MEMORY UPDATE:** Include the JSON MEMORY\_UPDATE\_PROTOCOL block at the very end.

### **4.3. Development Workflow (Dev Cycle)**

1. **Impact Analysis:** Silent analysis of consistency (Makefile, Volumes) before generation.  
2. **Bash Robustness:**  
   * Strict syntax: set \-euo pipefail.  
   * Variable protection: "$VAR".  
   * Error handling: Explicit checks (if \! command; then ... fi) for sensitive operations (dump, restore, stop).  
3. **Validation by Proof:**  
   * All changes must be verifiable via make test-\*.  
   * Modifications require updating test\_\*.sh scripts.  
   * Producing HTML reports for documentation is required.  
4. **Git Protocol:**  
   * Commit immediately after make test-\* validation.  
   * Use **Conventional Commits** (feat:, fix:, chore:, docs:).  
   * Single branch approach (main).

### **4.4. Security (Lab Context)**

* **Disabled Rule:** Embedding sensitive data (e.g., default passwords like rootpass) is **ALLOWED** for this lab environment (must be documented in README).  
* **General:** Stability and security remain priorities.
