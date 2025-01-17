alias ls := list
alias rs := reset
alias view := serve
alias server := serve

_listing:
	@just --list --no-aliases --unsorted \
		--list-heading=$'\e[34m{{justfile()}}\e[m\n' \
		--list-prefix=' • ' | sed -e 's/ • \[/[/'

[group("manage")]
list: _cache
	#!/bin/bash
	{{sql}} -box "SELECT
		FORMAT('%04d', weight) AS 'Weight',
		FORMAT('%s.md', code) AS 'File',
		title AS 'Title'
		FROM books
		ORDER BY weight+0;"

[group("manage")]
details *$book: _cache
	#!/bin/bash
	condition="%${book}%"
	[ -z "${book}" ] && condition="%"
	{{sql}} -line "SELECT * FROM books
		WHERE title LIKE '${condition}'
		OR code LIKE '${condition}';"

[group("manage")]
check:
	#!/usr/bin/perl
	use strict;
	my @template = split(/\n/, "{{template}}");
	foreach my $livre (glob("content/livres/*.md")) {
		print "$livre: ";
		open(my $fh, '<', $livre) or die "nope: $!";
		my $discard = <$fh>; # skip first line, i.e. first "---"
		my @keys;
		while(my $line = <$fh>) {
			if ($line =~ /^\s*#/) { last } # skip comments
			# skip everything after the second "---":
			if ($line =~ "---") { last } 
			my @bits = split(/\s+/, $line); push(@keys, $bits[0]);
		}
		if (join(',', @keys) eq join(',', @template)) { # compare arrays
			print "\e[32mok\e[m\n";
		} else {
			print "\e[\r31m$livre: \e[1mfailed!\e[m\n";
		}
		close($fh);
	}

# legacy, slow
[group("manage")]
[private]
check-bash:
	#!/bin/bash
	for livre in content/livres/*.md; do
		keys= ; flag=0 ; while IFS= read -r line; do
			[ "${line}" == "---" ] && {
				case $flag in 0) flag=1 ; continue ;; 1) break ;; esac
			}
			key=$(awk '{print $1}' <<< "${line}")
			keys=$(printf "%s\n%s" "${keys}" "${key}")
		done < "${livre}"
		echo -n "$(basename ${livre}): "
		diff <(echo "{{template}}") <(echo "${keys}" | sed 1d) && {
			ok ok
		} || {
			fail "$(basename ${livre}) failed"
		}
	done

[group("manage")]
sql:
	@{{sql}}

[group("manage")]
template:
	#!/bin/bash
	echo "---"
	echo "{{template}}"
	echo "---"
	echo

[group("hugo")]
clean:
	rm -rf public

[group("hugo")]
compile:
	hugo --gc --minify -b https://liberinvictus.com

[group("hugo")]
serve:
	hugo server --disableFastRender --enableGitInfo --bind 0.0.0.0

[group("hugo")]
publish: clean compile
	#!/bin/bash
	header "\n   Deploy manually to https://pages.cloudflare.com\n"

[group("hugo")]
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
template := "title:
subtitle:
date:
weight:
draft:
image:
isbn:
pages:
price:
amazon:
kindle:
kobo:"

set shell := ["bash","-uc"]
