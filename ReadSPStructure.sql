DECLARE @Name NVARCHAR(200) = N'usp_ClaimHeaderGroupValidateAmountPay_Select';
DECLARE @SQL  NVARCHAR(MAX);

SELECT 
    PARAMETER_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    PARAMETER_MODE
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE SPECIFIC_NAME = @Name;



DECLARE @proc SYSNAME = @Name;

BEGIN TRY
    SELECT 
        name              AS ColumnName,
        system_type_name  AS DataType,
        is_nullable,
        column_ordinal
    FROM sys.dm_exec_describe_first_result_set_for_object(
        OBJECT_ID(@proc), NULL
    );
END TRY
BEGIN CATCH

    SELECT 
        CAST(NULL AS sysname)       AS ColumnName,
        CAST(NULL AS nvarchar(100)) AS DataType,
        CAST(NULL AS bit)           AS is_nullable,
        CAST(NULL AS int)           AS column_ordinal
    WHERE 1=0;  
END CATCH;
