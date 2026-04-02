MLPI=./mlpi.pl
MLPC=./mlpc.pl
MLPC_OPT=./mlpc_opt.pl


test:: test_call test_freeze test_dcg_in test_dcg_out

clean:
	rm -f samples/test_call.pl samples/test_freeze.pl

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
