return {
    source_dir = '',
    build_dir = '',
    include_dir = {
		'include/openmw/',
		'scripts',
	},
    gen_target = '5.1',
	scripts = {
		build = {
			pre = "pre_build.lua"
		}
	}
}
