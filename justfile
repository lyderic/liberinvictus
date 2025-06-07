alias ls := list
alias rs := reset
alias view := serve
alias server := serve

_listing:
	@just --list --no-aliases --unsorted \
		--list-heading=$'\e[34m{{justfile()}}\e[m\n' \
		--list-prefix=' • ' | sed -e 's/ • \[/[/'

[group("sqlpage")]
sqlpage: _link_images
	sqlpage -w sqlpage -d sqlpage

_link_images:
	@[ -e sqlpage/images ] || ln -s ../static/media sqlpage/images

# backup database
backup:
	cp -iv db.db /dev/shm/db_$(date +%F_%T).db
	sqlite3 db.db .dump | gzip -v9 > backup.sql.gz

list:
	#!/bin/bash
	{{sql}} -box "SELECT
		PRINTF('%04d', weight) AS 'Weight',
		PRINTF('%s.md', id) AS 'File',
		title AS 'Title'
		FROM books
		ORDER BY weight;"

# generate markdown files
[group("manage")]
generate:
	#!/usr/bin/env lua
	require "lee"
	fh = io.open("content/livres/template.tmpl")
	data = ea([[{{sql}} -json "SELECT * FROM books;"]])
	books = json.decode(data)
	for _,book in ipairs(books) do
		local dst = f("/dev/shm/%s.md", book.code)
		local o = io.open(dst, "w")
		for line in fh:lines() do
			if line:find("%[") then
				item = line:match("%[(.-)%]")
				value = book[item]
				line = line:gsub("%[.-%]", value or "")
			end
			o:write(line.."\n"); goto next
		::next:: end
		fh:seek("set")
		o:close()
		print("ok", dst)
	end
	fh:close()

[group("manage")]
sql *args:
	@{{sql}} {{args}}

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

_check_deps:
	@pacman -Q go-yq > /dev/null

dump:
	{{sql}} .dump

schema:
	{{sql}} .schema

[private]
reset:
	@rm -f "${db}" "${ddb}" "${jcache}" "${lcache}"

[private]
v:
	just --evaluate

sql := "sqlite3 db.db"

set shell := ["bash","-uc"]
set export
