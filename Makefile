MLPI=./mlpi.pl
MLPC=./mlpc.pl
MLPC_OPT=./mlpc_opt.pl


test:: check-tools test_call test_freeze test_dcg_in test_dcg_out

hello:: hello_mlpi hello_mlpc hello_mlpc_opt
collatz:: collatz_mlpi collatz_mlpc collatz_mlpc_opt
primes:: primes_mlpi primes_mlpc primes_mlpc_opt
primes2:: primes2_mlpi primes2_mlpc primes2_mlpc_opt
queen:: queen_mlpi queen_mlpc queen_mlpc_opt

clean:
	rm -f samples/*.pl bootstrap/*.pl

check-tools::
	@command -v swipl >/dev/null 2>&1 || { \
		echo "error: swipl not found. Please install SWI-Prolog."; \
		exit 127; \
	}

test_call:: test_mlpi_call test_mlpc_call test_mlpc_opt_call
test_freeze:: test_mlpi_freeze test_mlpc_freeze test_mlpc_opt_freeze
test_dcg_in:: test_mlpi_dcg_in test_mlpc_dcg_in test_mlpc_opt_dcg_in
test_dcg_out:: test_mlpi_dcg_out test_mlpc_dcg_out test_mlpc_opt_dcg_out

test_mlpi_call::
	./mlpi.pl samples/test_call.mlp builtin.mlp
test_mlpc_call::
	./mlpc.pl samples/test_call.mlp builtin.mlp > samples/test_call.pl; \
	chmod +x samples/test_call.pl; \
	samples/test_call.pl
test_mlpc_opt_call::
	./mlpc_opt.pl samples/test_call.mlp builtin.mlp > samples/test_call.pl; \
	chmod +x samples/test_call.pl; \
	samples/test_call.pl
test_mlpi_freeze::
	./mlpi.pl samples/test_freeze.mlp builtin.mlp
test_mlpc_freeze::
	./mlpc.pl samples/test_freeze.mlp builtin.mlp > samples/test_freeze.pl; \
	chmod +x samples/test_freeze.pl; \
	samples/test_freeze.pl
test_mlpc_opt_freeze::
	./mlpc_opt.pl samples/test_freeze.mlp builtin.mlp > samples/test_freeze.pl; \
	chmod +x samples/test_freeze.pl; \
	samples/test_freeze.pl
test_mlpi_dcg_in:
	./mlpi.pl samples/test_dcg_in.mlp builtin.mlp
test_mlpc_dcg_in::
	./mlpc.pl samples/test_dcg_in.mlp builtin.mlp > samples/test_dcg_in.pl; \
	chmod +x samples/test_dcg_in.pl; \
	samples/test_dcg_in.pl
test_mlpc_opt_dcg_in::
	./mlpc_opt.pl samples/test_dcg_in.mlp builtin.mlp > samples/test_dcg_in.pl; \
	chmod +x samples/test_dcg_in.pl; \
	samples/test_dcg_in.pl

test_mlpi_dcg_out:
	./mlpi.pl samples/test_dcg_out.mlp builtin.mlp
test_mlpc_dcg_out::
	./mlpc.pl samples/test_dcg_out.mlp builtin.mlp > samples/test_dcg_out.pl; \
	chmod +x samples/test_dcg_out.pl; \
	samples/test_dcg_out.pl
test_mlpc_opt_dcg_out::
	./mlpc_opt.pl samples/test_dcg_out.mlp builtin.mlp > samples/test_dcg_out.pl; \
	chmod +x samples/test_dcg_out.pl; \
	samples/test_dcg_out.pl

hello_mlpi::
	./mlpi.pl samples/hello.mlp builtin.mlp -- mlpi.
hello_mlpc::
	./mlpc.pl samples/hello.mlp builtin.mlp > samples/hello.pl; \
	chmod +x samples/hello.pl; \
	samples/hello.pl mlpc
hello_mlpc_opt::
	./mlpc_opt.pl samples/hello.mlp builtin.mlp > samples/hello.pl; \
	chmod +x samples/hello.pl; \
	samples/hello.pl mlpc_opt

collatz_mlpi::
	time ./mlpi.pl samples/collatz.mlp builtin.mlp -- 1234567
collatz_mlpc::
	./mlpc.pl samples/collatz.mlp builtin.mlp > samples/collatz.pl; \
	chmod +x samples/collatz.pl; \
	ls -l samples/collatz.pl; \
	time samples/collatz.pl 1234567
collatz_mlpc_opt::
	./mlpc_opt.pl samples/collatz.mlp builtin.mlp > samples/collatz.pl; \
	chmod +x samples/collatz.pl; \
	ls -l samples/collatz.pl; \
	time samples/collatz.pl 1234567

primes_mlpi::
	time ./mlpi.pl samples/primes.mlp builtin.mlp -- 10000
primes_mlpc::
	./mlpc.pl samples/primes.mlp builtin.mlp > samples/primes.pl; \
	chmod +x samples/primes.pl; \
	ls -l samples/primes.pl; \
	time samples/primes.pl 10000
primes_mlpc_opt::
	./mlpc_opt.pl samples/primes.mlp builtin.mlp > samples/primes.pl; \
	chmod +x samples/primes.pl; \
	ls -l samples/primes.pl; \
	time samples/primes.pl 10000

primes2_mlpi::
	time ./mlpi.pl samples/primes2.mlp builtin.mlp -- 10000
primes2_mlpc::
	./mlpc.pl samples/primes2.mlp builtin.mlp > samples/primes2.pl; \
	chmod +x samples/primes2.pl; \
	ls -l samples/primes2.pl; \
	time samples/primes2.pl 10000
primes2_mlpc_opt::
	./mlpc_opt.pl samples/primes2.mlp builtin.mlp > samples/primes2.pl; \
	chmod +x samples/primes2.pl; \
	ls -l samples/primes2.pl; \
	time samples/primes2.pl 10000

queen_mlpi::
	time ./mlpi.pl samples/queen.mlp builtin.mlp -- 10 |tail
queen_mlpc::
	./mlpc.pl samples/queen.mlp builtin.mlp > samples/queen.pl; \
	chmod +x samples/queen.pl; \
	ls -l samples/queen.pl; \
	time samples/queen.pl 10 |tail
queen_mlpc_opt::
	./mlpc_opt.pl samples/queen.mlp builtin.mlp > samples/queen.pl; \
	chmod +x samples/queen.pl; \
	ls -l samples/queen.pl; \
	time samples/queen.pl 10 |tail

# ----------------------------------------------------------------------
# generate mlpc.pl
# ----------------------------------------------------------------------
bootstrap/mlpc.stg3.pl: src/mlpc.mlp src/mlpc_runtime.mlp builtin.mlp
	mkdir -p bootstrap && \
	swipl mlpi.pl -- src/mlpc.mlp src/mlpc_runtime.mlp builtin.mlp -- src/mlpc.mlp src/mlpc_runtime.mlp builtin.mlp > bootstrap/mlpc.stg1.pl && \
	swipl bootstrap/mlpc.stg1.pl -- src/mlpc.mlp src/mlpc_runtime.mlp builtin.mlp > bootstrap/mlpc.stg2.pl && \
	swipl bootstrap/mlpc.stg2.pl -- src/mlpc.mlp src/mlpc_runtime.mlp builtin.mlp > bootstrap/mlpc.stg3.pl && \
	diff bootstrap/mlpc.stg2.pl bootstrap/mlpc.stg3.pl
mlpc.pl: bootstrap/mlpc.stg3.pl
	if [ -s bootstrap/mlpc.stg3.pl ]; then \
	  install bootstrap/mlpc.stg3.pl -m 755 mlpc.pl; \
	fi

# ----------------------------------------------------------------------
# generate mlpc_opt.pl
# ----------------------------------------------------------------------
bootstrap/mlpc_opt.stg3.pl:: src/mlpc_opt.mlp src/mlpc_opt_runtime.mlp builtin.mlp
	mkdir -p bootstrap && \
	swipl ./mlpi.pl -- src/mlpc_opt.mlp src/mlpc_opt_runtime.mlp builtin.mlp -- src/mlpc_opt.mlp src/mlpc_opt_runtime.mlp builtin.mlp > bootstrap/mlpc_opt.stg1.pl && \
	swipl bootstrap/mlpc_opt.stg1.pl -- src/mlpc_opt.mlp src/mlpc_opt_runtime.mlp builtin.mlp > bootstrap/mlpc_opt.stg2.pl && \
	swipl bootstrap/mlpc_opt.stg2.pl -- src/mlpc_opt.mlp src/mlpc_opt_runtime.mlp builtin.mlp > bootstrap/mlpc_opt.stg3.pl && \
	diff bootstrap/mlpc_opt.stg2.pl bootstrap/mlpc_opt.stg3.pl
mlpc_opt.pl: bootstrap/mlpc_opt.stg3.pl
	if [ -s bootstrap/mlpc_opt.stg3.pl ]; then \
	  install bootstrap/mlpc_opt.stg3.pl -m 755 mlpc_opt.pl; \
	fi

# ----------------------------------------------------------------------
# generate repl.pl
# ----------------------------------------------------------------------
repl.pl: src/repl.mlp mlpc.pl
	swipl mlpc.pl -- src/repl.mlp builtin.mlp > repl.pl; \
	chmod +x repl.pl
