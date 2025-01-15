alias ls := list
alias rs := reset
alias view := serve
alias server := serve

_listing:
	@just --list --no-aliases --unsorted \
		--list-heading=$'\e[34m{{justfile()}}\e[m\n' \
		--list-prefix=' • ' | sed -e 's/ • \[/[/'

list: _cache
	#!/bin/bash
	{{sql}} -box "SELECT
		FORMAT('%04d', weight) AS 'Weight',
		FORMAT('%s.md', code) AS 'File',
		title AS 'Title'
		FROM books
		ORDER BY weight+0;"

details *$book:
	#!/bin/bash
	condition="%${book}%"
	[ -z "${book}" ] && condition="%"
	{{sql}} -line "SELECT * FROM books
		WHERE title LIKE '${condition}'
		OR code LIKE '${condition}';"

clean:
	rm -rf public

compile:
	hugo --gc --minify -b https://liberinvictus.com

serve:
	hugo server --disableFastRender --enableGitInfo --bind 0.0.0.0

publish: clean compile
	#!/bin/bash
	header "\n   Deploy manually to https://pages.cloudflare.com\n"

httpd: publish
	busybox httpd -f -vv -p 8899 -h public

_cache:
	#!/bin/bash
	exec 1>&2
	[ -f "${db}" ] && exit 0
	printf "caching..."
	pacman -Q go-yq > /dev/null || die "missing go-yq package!"
	metadata=
	for livre in content/livres/*.md; do
		codeline="- code: $(basename "${livre}" .md)"
		metadata=$(printf "%s\n%s" "${metadata}" "${codeline}")
		flag=0
		while IFS= read -r line; do
			[ "${line}" == "---" ] && {
				case $flag in 0) flag=1 ; continue ;; 1) break ;; esac
			}
			metadata=$(printf "%s\n  %s" "${metadata}" "${line}")
		done < "${livre}"
	done
	csv=$(echo "${metadata}" | yq -o=csv)
	echo "${csv}" | {{sql}} -csv ".import /dev/stdin books"
	printf "\r\e[K"

tst:
	#!/bin/bash
	for livre in content/livres/*.md; do
		flag=0
		while IFS= read -r line; do
			[[ "${line}" =~ "---" ]] && {
				case $flag in
					0) flag=1 ; continue ;;
					1) break ;;
				esac
			}
			echo "> ${line}"
		done < "${livre}"
	done

[private]
dump:
	{{sql}} .dump

[private]
schema:
	{{sql}} .schema

[private]
reset: && _cache
	@rm -f "${db}"

[private]
v:
	just --evaluate

export db := "/dev/shm/liberinvictus.db"
sql := "sqlite3 " + db

set shell := ["bash","-uc"]
