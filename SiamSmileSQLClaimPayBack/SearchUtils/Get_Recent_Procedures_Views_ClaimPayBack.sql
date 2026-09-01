USE ClaimPayBack;
GO

SELECT 
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc,
    o.create_date AS CreatedDate,
    o.modify_date AS LastModifiedDate
FROM sys.objects o
LEFT JOIN sys.schemas s 
    ON o.schema_id = s.schema_id
WHERE 
    s.name in ('dbo','claim')  
    AND o.type IN ('P', 'V')  
    --AND o.type IN ('P', 'V', 'U', 'FN', 'IF', 'TF')  
    -- P = Stored Procedure, U = Table, V = View
    -- FN = Scalar Function, IF = Inline Table Function,
    --TF = Table-valued Function
ORDER BY 
    o.modify_date DESC;