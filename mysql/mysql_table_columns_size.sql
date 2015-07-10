# this query counts maximum size for each column from specified table

-- 18 = Index Record Header (5) + Transaction ID (6) + Roll Pointer (7)
SET @schema = 'write here your scheme';
SET @table = 'write here your table';

SELECT
  B.TABLE_SCHEMA AS 'schema'
  , B.TABLE_NAME AS 'table'
  , B.COLUMN_NAME AS 'column'
  , ROUND(B.FIELD_BYTE_SPACE + B.PK_BYTES + B.IX_BYTES) AS avg_col_zise
  , ROUND(B.FIELD_BYTE_SPACE + B.PK_BYTES + B.IX_BYTES) * T.TABLE_ROWS AS total_col_size
FROM
  (
    SELECT
      A.TABLE_SCHEMA
      , A.TABLE_NAME
      , A.COLUMN_NAME
      , A.FIELD_BYTE_SPACE
      , CASE WHEN A.COLUMN_KEY = 'PRI'
      THEN ((CASE WHEN FIELD_BYTE_SPACE = 0
        THEN 6
             ELSE FIELD_BYTE_SPACE END) + 18)
        ELSE 0
        END AS PK_BYTES
      , CASE WHEN A.COLUMN_KEY <> 'PRI'
                  AND A.COLUMN_KEY <> ''
      THEN (PK_BYTE_SPACE + FIELD_BYTE_SPACE)
        ELSE 0
        END AS IX_BYTES
    FROM
      (
        SELECT
          PK_SP.TABLE_SCHEMA
          , PK_SP.TABLE_NAME
          , PK_SP.COLUMN_NAME
          , COLUMN_KEY
          , (CASE -- CHARACTER FIELDS
             WHEN DATA_TYPE = 'varchar'
               THEN CHARACTER_OCTET_LENGTH + 1
             WHEN DATA_TYPE = 'char'
               THEN CHARACTER_OCTET_LENGTH
             WHEN DATA_TYPE = 'tinyblob' OR DATA_TYPE = 'tinytext'
               THEN CHARACTER_OCTET_LENGTH + 1
             WHEN DATA_TYPE = 'blob' OR DATA_TYPE = 'text'
               THEN CHARACTER_OCTET_LENGTH + 2
             WHEN DATA_TYPE = 'mediumblob' OR DATA_TYPE = 'mediumtext'
               THEN CHARACTER_OCTET_LENGTH + 3
             WHEN DATA_TYPE = 'largeblob' OR DATA_TYPE = 'largetext'
               THEN CHARACTER_OCTET_LENGTH + 4
             -- NUMERIC FIELDS
             WHEN DATA_TYPE = 'tinyint'
               THEN 1
             WHEN DATA_TYPE = 'smallint'
               THEN 2
             WHEN DATA_TYPE = 'mediumint'
               THEN 3
             WHEN DATA_TYPE = 'int' OR DATA_TYPE = 'integer'
               THEN 4
             WHEN DATA_TYPE = 'bigint'
               THEN 8
             WHEN DATA_TYPE = 'float' AND (NUMERIC_PRECISION <= 24 OR NUMERIC_PRECISION IS NULL)
               THEN 4
             WHEN DATA_TYPE = 'float' AND NUMERIC_PRECISION > 24
               THEN 8
             WHEN DATA_TYPE = 'bit'
               THEN (NUMERIC_PRECISION + 7) / 8
             WHEN DATA_TYPE = 'double' OR DATA_TYPE = 'numeric'
               THEN (FLOOR(NUMERIC_PRECISION / 9) * 4)
                    + ROUND((NUMERIC_PRECISION - FLOOR(NUMERIC_PRECISION / 9) * 9) * .5, 0)
             -- DATETIME FIELDS
             WHEN DATA_TYPE = 'date' OR DATA_TYPE = 'time'
               THEN 3
             WHEN DATA_TYPE = 'datetime'
               THEN 8
             WHEN DATA_TYPE = 'timestamp'
               THEN 4
             WHEN DATA_TYPE = 'year'
               THEN 1
             -- BINARY FIELDS
             WHEN DATA_TYPE = 'binary'
               THEN CHARACTER_MAXIMUM_LENGTH
             -- set enum
             WHEN DATA_TYPE = 'enum'
               THEN CASE
                    WHEN (LENGTH(COLUMN_TYPE) - LENGTH(REPLACE(COLUMN_TYPE, ",", "")) + 1) > 255
                      THEN 2
                    ELSE 1
                    END
             WHEN DATA_TYPE = 'set'
               THEN CEIL((LENGTH(COLUMN_TYPE) - LENGTH(REPLACE(COLUMN_TYPE, ",", "")) + 1) / 8)
             ELSE 999999999999999 END) +
            (CASE WHEN IS_NULLABLE = 'YES'
              THEN 1
             ELSE 0 END) AS FIELD_BYTE_SPACE
          , CASE WHEN PK_BYTE_SPACE IS NULL
          THEN 6 + 18
            ELSE PK_BYTE_SPACE + 18 END AS PK_BYTE_SPACE
        FROM information_schema.columns AS PK_SP
          LEFT JOIN
          (#detects size of table primary keys
            SELECT
              TABLE_SCHEMA
              , TABLE_NAME
              , SUM((CASE
                     -- CHARACTER FIELDS
                     WHEN DATA_TYPE = 'varchar'
                       THEN CHARACTER_OCTET_LENGTH + 1
                     WHEN DATA_TYPE = 'char'
                       THEN CHARACTER_OCTET_LENGTH
                     WHEN DATA_TYPE = 'tinyblob' OR DATA_TYPE = 'tinytext'
                       THEN CHARACTER_OCTET_LENGTH + 1
                     WHEN DATA_TYPE = 'blob' OR DATA_TYPE = 'text'
                       THEN CHARACTER_OCTET_LENGTH + 2
                     WHEN DATA_TYPE = 'mediumblob' OR DATA_TYPE = 'mediumtext'
                       THEN CHARACTER_OCTET_LENGTH + 3
                     WHEN DATA_TYPE = 'largeblob' OR DATA_TYPE = 'largetext'
                       THEN CHARACTER_OCTET_LENGTH + 4
                     -- NUMERIC FIELDS
                     WHEN DATA_TYPE = 'tinyint'
                       THEN 1
                     WHEN DATA_TYPE = 'smallint'
                       THEN 2
                     WHEN DATA_TYPE = 'mediumint'
                       THEN 3
                     WHEN DATA_TYPE = 'int' OR DATA_TYPE = 'integer'
                       THEN 4
                     WHEN DATA_TYPE = 'bigint'
                       THEN 8
                     WHEN DATA_TYPE = 'float'
                          AND (NUMERIC_PRECISION <= 24 OR NUMERIC_PRECISION IS NULL)
                       THEN 4
                     WHEN DATA_TYPE = 'float' AND NUMERIC_PRECISION > 24
                       THEN 8
                     WHEN DATA_TYPE = 'bit'
                       THEN (NUMERIC_PRECISION + 7) / 8
                     WHEN DATA_TYPE = 'double' OR DATA_TYPE = 'numeric'
                       THEN (FLOOR(NUMERIC_PRECISION / 9) * 4) +
                            ROUND((NUMERIC_PRECISION - FLOOR(NUMERIC_PRECISION / 9) * 9) * .5, 0)
                     -- DATETIME FIELDS
                     WHEN DATA_TYPE = 'date' OR DATA_TYPE = 'time'
                       THEN 3
                     WHEN DATA_TYPE = 'datetime'
                       THEN 8
                     WHEN DATA_TYPE = 'timestamp'
                       THEN 4
                     WHEN DATA_TYPE = 'year'
                       THEN 1
                     -- BINARY FIELDS
                     WHEN DATA_TYPE = 'binary'
                       THEN CHARACTER_MAXIMUM_LENGTH
                     -- set / enum
                     WHEN DATA_TYPE = 'enum'
                       THEN CASE
                            WHEN (LENGTH(COLUMN_TYPE) - LENGTH(REPLACE(COLUMN_TYPE, ",", "")) + 1) > 255
                              THEN 2
                            ELSE 1
                            END
                     WHEN DATA_TYPE = 'set'
                       THEN CEIL((LENGTH(COLUMN_TYPE) - LENGTH(REPLACE(COLUMN_TYPE, ",", "")) + 1) / 8)
                     ELSE 999999999999999 END)
                    + (CASE
                       WHEN IS_NULLABLE = 'YES'
                         THEN 1
                       ELSE 0 END)) AS PK_BYTE_SPACE
            FROM
              information_schema.columns
            WHERE
              COLUMN_KEY = 'PRI'
              AND TABLE_SCHEMA = @schema
              AND TABLE_NAME = @table
            GROUP BY
              TABLE_SCHEMA, TABLE_NAME) AS IX_SP
            ON PK_SP.TABLE_SCHEMA = IX_SP.TABLE_SCHEMA
               AND PK_SP.TABLE_NAME = IX_SP.TABLE_NAME
        WHERE
          PK_SP.TABLE_NAME = @table
          AND PK_SP.TABLE_SCHEMA = @schema) AS A) AS B
  LEFT JOIN information_schema.TABLES AS T
    ON T.TABLE_SCHEMA = B.TABLE_SCHEMA
       AND T.TABLE_NAME = B.TABLE_NAME;

