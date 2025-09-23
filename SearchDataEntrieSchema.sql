/* ✅ WORKS ON SQL SERVER <2017 (NO STRING_AGG), NO BOM NEEDED */

USE [ClaimPayBack];
GO

-- 🧠 INPUT (แก้ได้ตามต้องการ)
DECLARE @SearchValue_SQL NVARCHAR(100) = N'SEHO-888-68090044-0';--SEHO-888-68090044-0 SEHH-888-68090007-0
DECLARE @SchemaName      NVARCHAR(128) = N'dbo'; -- ใส่ชื่อสคีมา หรือให้เป็น NULL เพื่อค้นหาทุกสคีมา

-- 🔍 Detect input type
DECLARE @ValueType SYSNAME;
IF TRY_CAST(@SearchValue_SQL AS UNIQUEIDENTIFIER) IS NOT NULL
    SET @ValueType = 'uniqueidentifier';
ELSE IF TRY_CAST(@SearchValue_SQL AS INT) IS NOT NULL
    SET @ValueType = 'int';
ELSE IF TRY_CAST(@SearchValue_SQL AS BIGINT) IS NOT NULL
    SET @ValueType = 'bigint';
ELSE IF TRY_CAST(@SearchValue_SQL AS DATETIME) IS NOT NULL
    SET @ValueType = 'datetime';
ELSE
    SET @ValueType = 'nvarchar';

PRINT 'Detected type = ' + @ValueType;

-- 🎯 เลือกเฉพาะคอลัมน์ที่ type เข้ากันได้
IF OBJECT_ID('tempdb..#Targets') IS NOT NULL DROP TABLE #Targets;
CREATE TABLE #Targets
(
    SchemaName SYSNAME,
    TableName  SYSNAME,
    ColumnName SYSNAME,
    TypeName   SYSNAME
);

INSERT INTO #Targets (SchemaName, TableName, ColumnName, TypeName)
SELECT
    s.name,
    t.name,
    c.name,
    ty.name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id  -- ใช้ชื่อ type ตรง ๆ ปลอดภัยกว่าเทียบ type_id ตัวเลข
WHERE
    (@SchemaName IS NULL OR s.name = @SchemaName)
    AND ty.is_user_defined = 0
    AND (
        (@ValueType = 'uniqueidentifier' AND ty.name = 'uniqueidentifier')
        OR (@ValueType = 'int'           AND ty.name IN ('int','smallint','tinyint'))
        OR (@ValueType = 'bigint'        AND ty.name IN ('bigint','int'))
        OR (@ValueType = 'datetime'      AND ty.name IN ('datetime','smalldatetime','date','time','datetime2','datetimeoffset'))
        OR (@ValueType = 'nvarchar'      AND ty.name IN ('nvarchar','nchar','varchar','char')) -- ไม่รองรับ text/ntext ที่เลิกใช้แล้ว
    );

DECLARE @found BIT = 0;

-- 🔁 วนลูปทีละคอลัมน์และค้นหาแบบปลอดภัยด้วย sp_executesql
DECLARE @S SYSNAME, @T SYSNAME, @C SYSNAME, @Ty SYSNAME;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT SchemaName, TableName, ColumnName, TypeName FROM #Targets;

OPEN cur;
FETCH NEXT FROM cur INTO @S, @T, @C, @Ty;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @cnt INT = 0;
    DECLARE @sql NVARCHAR(MAX) =
N'SELECT @cnt = COUNT(1)
  FROM ' + QUOTENAME(@S) + N'.' + QUOTENAME(@T) + N'
 WHERE TRY_CONVERT(NVARCHAR(MAX), ' + QUOTENAME(@C) + N') = @val;';

    EXEC sp_executesql
        @sql,
        N'@val NVARCHAR(MAX), @cnt INT OUTPUT',
        @val = @SearchValue_SQL, @cnt = @cnt OUTPUT;

    IF @cnt > 0
    BEGIN
        SET @found = 1;
        PRINT 'Found in: ' + @S + '.' + @T + '.' + @C + ' (' + @Ty + ') Count=' + CAST(@cnt AS NVARCHAR(20));

        -- ⚠️ ถ้าข้อมูลอาจเยอะ แนะนำใช้ TOP (200) / เพิ่ม WHERE อื่น ๆ เอง
        DECLARE @sel NVARCHAR(MAX) =
N'SELECT ''' + @S + N'.' + @T + N''' AS TableName,
         ''' + @C + N''' AS ColumnName,
         *
  FROM ' + QUOTENAME(@S) + N'.' + QUOTENAME(@T) + N'
 WHERE TRY_CONVERT(NVARCHAR(MAX), ' + QUOTENAME(@C) + N') = @val;';

        EXEC sp_executesql
            @sel,
            N'@val NVARCHAR(MAX)',
            @val = @SearchValue_SQL;
    END

    FETCH NEXT FROM cur INTO @S, @T, @C, @Ty;
END

CLOSE cur;
DEALLOCATE cur;

IF @found = 0
    PRINT 'Not found';
