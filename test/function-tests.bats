#!/home/abreha.b/bats-core/bin bats

@test "renaming existing slurm output files" {
	cd $TEST_TMP
	touch 00000000_01.o 00000000_01.e
	i=$(ls 00000000_01.* | wc -l)
	j=$(ls file_name.* 2>/dev/null | wc -l)
	[ "$i" -eq 2 ]
	[ "$j" -eq 0 ]
	run rename_slurm_outputs 01 file_name
	i=$(ls 00000000.* | wc -l)
    j=$(ls file_name.* | wc -l)	
    [ "$i" -eq 0 ]
    [ "$j" -eq 2 ]
	rm file_name*
}
