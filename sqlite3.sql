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
    b.skips,
	r.operatorbundle_name,
    c.head_operatorbundle_name,
    p.default_channel
FROM
	channel_entry e
LEFT JOIN
	channel_entry r ON r.entry_id = e.replaces
LEFT JOIN
	operatorbundle b ON e.operatorbundle_name = b.name
LEFT JOIN
    channel c ON e.package_name = c.package_name AND e.channel_name = c.name
LEFT JOIN
    package p on c.package_name = p.name;
-- `exit 1` suppresses sqlite output at end of execution and just quits
.exit 1
