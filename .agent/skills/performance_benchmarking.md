---
trigger: explicit_call
description: Execute performance tests and generate analytical reports.
category: skill
---
# Performance Benchmarking

## 🧠 Rationale

The primary goal of this laboratory is performance analysis. This skill codifies the execution of automated test suites and the generation of standardized reports.

## 🛠️ Implementation

- **Run All Tests**: `make test-all`.
- **Specific Test**: `bash ./tests/test_perf_repli.sh light run`.
- **Report Generation**: Reports are automatically saved to the `reports/` directory in HTML and Markdown.

## ✅ Verification

- Confirm new `.md` or `.html` files in `reports/`.
- Audit logs for sysbench execution completion.
