alias ls := list
alias rs := reset
alias view := serve
alias server := serve

_listing:
	@just --list --no-aliases --unsorted \
		--list-heading=$'\e[34m{{justfile()}}\e[m\n' \
		--list-prefix=' • ' | sed -e 's/ • \[/[/'

list:
	#!/bin/bash
	{{sql}} -box "SELECT
		PRINTF('%04d', weight) AS 'Weight',
		PRINTF('%s.md', code) AS 'File',
		title AS 'Title'
		FROM books
		ORDER BY weight;"

[group("sqlpage")]
sqlpage: _link_images
	sqlpage -w sqlpage -d sqlpage

_link_images:
	@[ -e sqlpage/images ] || ln -s ../static/media sqlpage/images

# generate content markdown files
[group("manage")]
generate:
	#!/usr/bin/env lua
	require "lee"
	dir = "content/livres"
	x("mkdir -pv "..dir)
	fh = io.open("templates/livre.tmpl")
	data = ea([[{{sql}} -json "SELECT * FROM books;"]])
	books = json.decode(data)
	for _,book in ipairs(books) do
		--local dst = f(dir.."/%s.md", book.code)
		local dst = f(dir.."/%s.md", book.code)
		local o = io.open(dst, "w")
		for line in fh:lines() do
			if line:find("%[") then -- '[' and ']' escaped with '%'
				item = line:match("%[(.-)%]")
				line = line:gsub("%[.-%]", book[item] or "")
			end
			o:write(line.."\n"); goto next
		::next:: end
		fh:seek("set")
		o:close()
		print("ok", dst)
	end
	fh:close()

# connect to database
[group("database")]
sql:
	@{{sql}}

# database console dump
[group("database")]
dump:
	@{{sql}} .dump

# database schema
[group("database")]
schema:
	{{sql}} .schema

# backup database
[group("database")]
backup:
	#!/bin/bash
	cp -iv db.db /dev/shm/db_$(date +%F_%T).db
	dst=backup.sql.gz 
	just dump | gzip -v9 > $dst && ok $dst

[group("hugo")]
clean:
	rm -rf public
	rm -rf content/livres

[group("hugo")]
build: generate
	hugo --gc --minify -b https://liberinvictus.com

[group("hugo")]
serve: build
	hugo server --disableFastRender --enableGitInfo --bind 0.0.0.0

[group("hugo")]
publish: clean build
	#!/bin/bash
	header "\n   Deploy manually to https://pages.cloudflare.com\n"

[group("hugo")]
httpd: publish
	busybox httpd -f -vv -p 8899 -h public

[private]
reset:
	@rm -f "${db}" "${ddb}" "${jcache}" "${lcache}"

[private]
v:
	just --evaluate

sql := "sqlite3 db.db"

set shell := ["bash","-uc"]
set export
