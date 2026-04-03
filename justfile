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
	$sql -box "SELECT
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
	#!/usr/bin/env -S lua -llee
	dir = "content/livres"
	x("mkdir -pv "..dir)
	tmpl = io.open("templates/livre.tmpl")
	data = ea("%s -json 'SELECT * FROM books;'", env("sql"))
	books = json.decode(data)
	for _,book in ipairs(books) do
		local dst = f("%s/%s.md", dir, book.code)
		local o = io.open(dst, "w")
		for line in tmpl:lines() do
			if line:find("%[") then -- [ and ] escaped with '%'
				local key = line:match("%[(.-)%]")
				local item,n = line:gsub("%[.-%]", book[key] or "")
				if n ~= 1 then error("error in line: "..line) end
				o:write(item.."\n")
			else
				o:write(line.."\n")
			end
		end
		o:close()
		tmpl:seek("set")
		print("ok", dst)
	end
	tmpl:close()

# connect to database
[group("database")]
sql:
	@$sql

# database console dump
[group("database")]
dump:
	@$sql .dump

# database schema
[group("database")]
schema:
	@$sql .schema

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
	incus file push --recursive --create-dirs public/* k:liber/srv/http
	incus exec k:liber -- systemctl restart darkhttpd.service

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
