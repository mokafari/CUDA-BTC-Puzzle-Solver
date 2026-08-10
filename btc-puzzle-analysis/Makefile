# btc-puzzle-analysis — analysis-only toolkit for the Bitcoin Puzzle Transaction.
# All targets run offline against cached/hardcoded data. No keyspace search.

PY ?= python
VENV ?= .venv

.PHONY: help venv install test report analyze fetch clean

help:
	@echo "make install  - create venv and install pinned deps"
	@echo "make test     - run the full pytest suite (offline)"
	@echo "make report   - regenerate all tables and plots into reports/"
	@echo "make analyze  - run A->B->C->D consolidated report"
	@echo "make fetch    - (optional) refresh cached chain data in data/"
	@echo "make clean    - remove generated report artifacts"

venv:
	$(PY) -m venv $(VENV)

install: venv
	. $(VENV)/bin/activate && pip install -e .

test:
	$(PY) -m pytest

report:
	$(PY) -m keygen.report
	$(PY) -m costmodel.plots
	$(PY) analyze.py --report

analyze:
	$(PY) analyze.py

fetch:
	$(PY) -m exposure.fetch --write

clean:
	rm -f reports/*.png reports/*.txt
