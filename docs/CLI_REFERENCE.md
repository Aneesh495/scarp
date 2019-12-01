# scarp CLI Reference Manual

The `scarp` command-line interface provides unified control over the seismic
early warning engine, C11 SIMD acceleration layer, Dis bytecode virtual machine,
and interactive visualization server.

## 1. Global Usage

```sh
python3 tools/scarp_cli.py <command> [options]
```

or via `make`:

```sh
make <target>
```

## 2. Subcommands

### 2.1 `doctor`
Runs system diagnostics verifying compiler availability, Python environment,
compiled dynamic libraries, Limbo source modules, and code formatting rules.

```sh
python3 tools/scarp_cli.py doctor
```

Output:
```
scarp Environment Diagnostics
============================================================
Python Version:   3.14.2
Platform:         darwin
Repository Root:  /path/to/scarp
C Accelerator:    OK (Loaded) -> build/libscarp_fast.dylib
Limbo Modules:    11 interface definitions (.m)
Limbo Programs:   35 implementations (.b)
Dash Linter:      PASS (0 forbidden dashes)
============================================================
All core engine diagnostics completed.
```

### 2.2 `pick`
Simulates or processes streaming seismic waveform traces using recursive STA/LTA
energy ratios and higher-order statistics kurtosis onset picking.

```sh
python3 tools/scarp_cli.py pick [--channel HNZ]
```

### 2.3 `locate`
Executes Geiger's non-linear least squares hypocenter inversion on synthetic or
recorded station arrival picks using 1D velocity models.

```sh
python3 tools/scarp_cli.py locate
```

### 2.4 `shakemap`
Generates a 2D ground motion field (PGA, PGV, MMI) for a specified moment magnitude.

```sh
python3 tools/scarp_cli.py shakemap --magnitude 6.8
```

Options:
- `--magnitude <float>`: Target moment magnitude $M_w$ (default: 6.5).

### 2.5 `bench`
Executes high-throughput latency and throughput benchmarks, outputting detailed
statistics and saving structured JSON telemetry to `benchmarks/benchmark_results.json`.

```sh
python3 tools/scarp_cli.py bench
```

### 2.6 `test`
Executes the comprehensive master test runner across unit tests, structure tests,
regression tests, and property-based fuzz tests.

```sh
python3 tools/scarp_cli.py test
```

### 2.7 `web`
Launches the zero-dependency interactive web workbench on the local host.

```sh
python3 tools/scarp_cli.py web [--port 8765] [--no-open]
```

Options:
- `--port <int>`: Local TCP port (default: 8765).
- `--no-open`: Prevents automatic browser launch.

## 3. Makefile Targets

```sh
make all       # Compile C11 SIMD library and build target
make build     # Build build/libscarp_fast.dylib
make test      # Run full test runner and em dash enforcement gate
make bench     # Execute performance benchmark suite
make lint      # Check zero forbidden dash violations
make web       # Start web workbench server
make clean     # Remove build artifacts and temporary logs
```
