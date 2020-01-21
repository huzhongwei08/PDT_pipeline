#!/home/abreha.b/bats-core/bin bats

# example test
# @test "addition using bc" {
#   result="$(echo 2+2 | bc)"
#   [ "$result" -eq 4 ]
# }


@test "making .com files" {
	cd $TEST_TMP
	cp $FLOW/test/envs/sample-structures/* .
	run bash $FLOW/scripts/make-com.sh -i=benzene.pdb -r='# b3lyp/tzvp opt' -t=benzene_pdb
	[ "$status" -eq 0 ]
	run bash $FLOW/scripts/make-com.sh -i=benzene.xyz -r='# b3lyp/tzvp opt' -t=benzene_xyz
	[ "$status" -eq 0 ]
	rm *
}

