SELECT 'shell' AS component,
	'Liber Invictus' AS title,
	'dark' AS theme;

SELECT 'text' AS component,
	"Liste des livres de **L**iber **I**nvictus" AS contents_md;

SELECT 'table' AS component,
	TRUE AS small,
	TRUE AS sort,
	'Amazon' AS markdown,
	'Kindle' AS markdown,
	'Kobo' AS markdown;

SELECT
	FORMAT('%04d', b.weight) AS 'Position',
	b.title AS 'Titre',
	FORMAT('[%s](%s/%s)', b.amazon, u.amazon, b.amazon) AS 'Amazon',
	FORMAT('[%s](%s/%s)', b.kindle, u.amazon, b.kindle) AS 'Kindle',
	FORMAT('[%s](%s/%s)', b.kobo, u.kobo, b.kobo)       AS 'Kobo'
FROM books AS b
JOIN urls AS u
ORDER BY b.weight;

SELECT 'card' AS component,
	'Présentation des ouvrages' AS title,
	3 AS columns;
SELECT
	title AS title,
	FORMAT('**%s** -- ', oneliner) AS description_md,
	presentation AS description_md
FROM books;
