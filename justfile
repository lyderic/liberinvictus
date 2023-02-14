_listing:
	@printf "${BLU}{{justfile()}}${NOC}\n"
	@just --unsorted --list --list-heading='' --list-prefix=' • ' \
		| grep -v 'alias for'

clean:
	rm -rf public

compile:
	hugo --gc --minify -b https://liberinvictus.com

serve:
	hugo server --disableFastRender --bind 0.0.0.0

set shell := ["bash","-uc"]
# vim: ft=make
