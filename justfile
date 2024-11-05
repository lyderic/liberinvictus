alias view := serve
alias server := serve

_listing:
	@printf "${BLU}{{justfile()}}${NOC}\n"
	@just --unsorted --list --list-heading='' --list-prefix=' • ' \
		| grep -v 'alias for'

clean:
	rm -rf public

compile:
	hugo --gc --minify -b https://liberinvictus.com

serve:
	hugo server --disableFastRender --enableGitInfo --bind 0.0.0.0

publish: clean compile

httpd: publish
	busybox httpd -f -vv -p 8899 -h public

set shell := ["bash","-uc"]
