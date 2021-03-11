.open olm_catalog_indexes/index.db.4.6.redhat-operators
.headers off
.output
SELECT
	e.package_name,
	e.channel_name,
	e.operatorbundle_name,
	e.depth,
	b.version,
	b.skipRange,
	r.operatorbundle_name
FROM
	channel_entry e
LEFT JOIN
	channel_entry r ON r.entry_id = e.replaces
LEFT JOIN
	operatorbundle b ON e.operatorbundle_name = b.name;
-- `exit 1` suppresses sqlite output at end of execution and just quits
.exit 1
