# utils-collection

Reusable shell scripts for system and development tasks.

---

## Scripts

### 1. `get_conda_env_size.sh`
Summarize disk usage of installed Conda environments.

Usage:
```bash
./get_conda_env_size.sh
```

Output Example:

```bash
Conda Environments Disk Usage:
------------------------------
base         1.23 GB
aud          2.45 GB
nlp          3.78 GB
```

### 2. llm_size.sh

Summarize disk usage of models managed by Ollama and LM Studio.

Usage:

```bash
./llm_size.sh [--verbose] [--debug] [--help]
```

Options:
	•	`--verbose` : Include raw output from `ollama ls` and `lms ls`.
	•	`--debug`   : Show detailed parsing logs (matched tokens, byte counts).
	•	`--help`    : Display usage guide.

Output Example (default):
```bash
Total Disk Space Used:   32.12 GB
----------------------------------
Ollama:        6 models taking up 36.40 GB of space
LM-Studio:     2 models taking up  5.00 GB of space
```
Output Example (--verbose):

```bash
Total Disk Space Used:   32.12 GB
----------------------------------
Ollama:        6 models taking up 36.40 GB of space
LM-Studio:     2 models taking up  5.00 GB of space
----------------------------------
Ollama models:
============
<full output of `ollama ls` here>

LM-Studio models:
============
<full output of `lms ls` here>

```

## Requirements
- POSIX shell (bash, zsh, etc.)
- awk
- For llm_size.sh:
	- [Ollama](https://ollama.com/)
	- [LM Studio](https://lmstudio.ai/)

Runs on Linux, macOS, or Windows (via WSL, Git Bash, or similar).

⸻

## Contributing

Add new reusable scripts under the repo. 

Keep each script:
- Self-contained
- With usage comments (--help)
- Portable across Linux/macOS

⸻

License: MIT

