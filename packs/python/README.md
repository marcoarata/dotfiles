# Pack Python

Python via mise, venv-based env, lint/format with ruff/black.

## Version
`.python-version` in the project (mise reads it). Override:
```toml
[tools]
python = "3.12"
```

## Usage
```sh
mise install
python -m venv .venv && source .venv/bin/activate
pip install ruff black
ruff check . && black --check .
```
