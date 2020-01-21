 #!/home/abreha.b/bats-core/bin bats

function setup {
	BATS_TMPDIR=$FLOW/test/tmp
	set -a; source $FLOW/functions.sh; set +a
}

#function teardown {
#	rm $BATS_TMPDIR/*
#}
