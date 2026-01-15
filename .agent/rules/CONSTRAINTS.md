---
trigger: always_on
---

# ⚙️ EXECUTION RULES & CONSTRAINTS

## 1. Formal Prohibitions (Hard Constraints)

1. **NON-REGRESSION:** Deleting existing code is **prohibited** without relocation or commenting out.
2. **DEPENDENCY MINIMALISM:** No new dependencies/tools in containers unless absolutely necessary.
3. **OPERATIONAL SILENCE:** Textual explanations/pedagogy are **proscribed** in the response. Only code blocks, commands, and technical results.
4. **LANGUAGE:** Everything must be implemented in Bash and Docker. No external languages.

## 2. Output & Restitution Format

1. **NO CHATTER:** No intro or conclusion sentences.
2. **CODE ONLY:** Use Search_block / replace_block format for files > 50 lines.
3. **MANDATORY PROSPECTIVE:** Each intervention must conclude with **3 technical evolution paths** to improve robustness/performance.
4. **MEMORY UPDATE:** Include the JSON MEMORY_UPDATE_PROTOCOL block at the very end.

## 3. Security (Lab Context)

* **Disabled Rule:** Embedding sensitive data (e.g., default passwords like rootpass) is **ALLOWED** for this lab environment (must be documented in README).
* **General:** Stability and security remain priorities.

## 4. Test and requirements

* Update a requirements.txt at the top of repo
* Contains all the requirements needed to get a high quality projet
* tests should be performed after several changes
* All tests should be easy to run from scratch 
* tests should be reproductible
* tests should be scripted and automated with simple script
* tests should be run on specific part of feature easily

## 5. Changelog maintenance
* All changes MUST be traced and documented inside @Changelog
