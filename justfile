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
llist: _lua_cache
	#!/usr/bin/env lua
	require "lee"
	livres = json.decode(readfile("{{lcache}}"))
	for _,e in ipairs(livres) do
		printf("[%03d]  %-18.18s %s\n", e.weight, e.filename, e.title)
	end
_lua_cache:
	#!/usr/bin/env lua
	require "lee"
	if x("test -f {{lcache}}") then os.exit(0) end
	livres = {}
	for file in e("find content/livres -type f"):lines() do
		filename, path = eo("basename "..file), abs(file)
		local livre = { path = path }
		livre = json.decode(ea("yq -o json -f extract "..path))
		livre.file, livre.filename, livre.path = file, filename, path
		table.insert(livres, livre)
	end
	table.sort(livres, function(a,b) return a.weight < b.weight end)
	writefile("{{lcache}}", json.encode(livres))

[group("manage")]
details *$book: _cache
	#!/bin/bash
	condition="%${book}%"
	[ -z "${book}" ] && condition="%"
	{{sql}} -line "SELECT * FROM books
		WHERE title LIKE '${condition}'
		OR code LIKE '${condition}';"

[group("manage")]
check: _check_awk

# what about this?
_check_awk:
	#!/bin/bash
	for livre in content/livres/*.md; do
		echo -n "$(basename ${livre}): "
		keys=$(awk '
			/^---$/ {if (marker) {exit} else {marker=1; next}} 
			marker {print $1}
		' "${livre}")
		diff <(echo "{{template}}") <(echo "${keys}") && {
			ok ok
		} || {
			fail "$(basename ${livre}) failed"
		}
	done

_document_check_awk:
	# Here the explanation of the awk blob used in _check_awk:
	# 
	# /^---$/ {if (marker) {exit} else {marker=1; next}}
	# marker {print $1}
	# 
	# - /^---$/: matches lines with three dashes 
	#
	# - {if (marker) {exit} else {marker=1; next}}:
	#   - This block is executed when a line matching the pattern (`/^---/`) is found.
	#   - if (marker) {exit}: This checks if the variable `marker` is already set. If it is, the script exits, stopping further processing of the input file.
	#   - else {marker=1; next}: If `marker` is not set (i.e., it is the first occurrence of a line with `---`), it sets `marker` to `1` (indicating that the marker has been encountered) and uses `next` to skip to the next line without executing any further actions for the current line.
	#
	# - marker {print $1}:
	#   - This block is executed for every line after the first occurrence of a line with `---`.
	#   - If `marker` is set (i.e., a line with `---` has been encountered), it prints the first field of the current line (`$1`). 

# quick, but... no diff!!!
_check_perl:
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
_check_bash:
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
build:
	hugo --gc --minify -b https://liberinvictus.com

[group("hugo")]
serve:
	hugo server --disableFastRender --enableGitInfo --bind 0.0.0.0

[group("hugo")]
publish: clean build
	#!/bin/bash
	header "\n   Deploy manually to https://pages.cloudflare.com\n"

[group("hugo")]
httpd: publish
	busybox httpd -f -vv -p 8899 -h public

_cache: _check_deps
	#!/bin/bash
	exec 1>&2
	[ -f "${db}" ] && exit 0
	printf "caching..."
	for livre in content/livres/*.md; do
		codeline="- code: $(basename "${livre}" .md)"
		metadata=$(awk '/^title/,/^kobo/ {print "  "$0}' "${livre}")
		#metadata=$(yq -f extract "${livre}")
		yaml=$(printf "%s\n%s\n%s\n" "${yaml}" "${codeline}" "${metadata}")
	done
	csv=$(echo "${yaml}" | yq -o=csv)
	echo "${csv}" | {{sql}} -csv ".import /dev/stdin books"
	printf "\r\e[K"

_check_deps:
	@pacman -Q go-yq > /dev/null

[private]
dump:
	{{sql}} .dump

[private]
schema:
	{{sql}} .schema

[private]
reset: && _cache
	@rm -f "${db}" "${lcache}"

[private]
v:
	just --evaluate

db := "/dev/shm/liberinvictus.db"
lcache := "/dev/shm/liberinvictus.lua"

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
set export
