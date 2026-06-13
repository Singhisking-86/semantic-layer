/* Example query — preview the orderline_current table.
 * Returns 10 rows; handy as a connection + schema smoke test.
 *
 *   python tools/teradata/pull.py --sql tools/teradata/sql/example.sql
 */
SELECT TOP 10 *
FROM PRODVM.ORDERLINE_CURRENT;
