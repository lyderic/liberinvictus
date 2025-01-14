alias view := serve
alias server := serve

_listing:
	@just --list --no-aliases --unsorted \
		--list-heading=$'\e[34m{{justfile()}}\e[m\n' \
		--list-prefix=' • ' | sed -e 's/ • \[/[/'

clean:
	rm -rf public

compile:
	hugo --gc --minify -b https://liberinvictus.com

serve:
	hugo server --disableFastRender --enableGitInfo --bind 0.0.0.0

publish: clean compile
	echo -e "\e[37mDeploy manually to https://pages.cloudflare.com\e[m"

httpd: publish
	busybox httpd -f -vv -p 8899 -h public

set shell := ["bash","-uc"]
