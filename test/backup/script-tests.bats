#!/home/abreha.b/bats-core/bin bats

# example test
# @test "addition using bc" {
#   result="$(echo 2+2 | bc)"
#   [ "$result" -eq 4 ]
# }

load test-setup

@test "determining the lowest energy conformer" {
	run bash $FLOW/scripts/get_lowest_conf_sp-dft.sh $FLOW/test/envs/lowest-energy-confs/AAACLBGNAMDLRM-UHFFFAOYSA-N
	conf_name=$(basename $output)
	[ "$status" -eq 0 ]
	[ "$conf_name" = "AAACLBGNAMDLRM-UHFFFAOYSA-N_2" ]
	echo "$BATS_TMPDIR" >&3
}
