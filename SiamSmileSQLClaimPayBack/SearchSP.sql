SELECT 
    o.name AS [ProcedureName]
    ,o.schema_id
    ,s.name AS [SchemaName]   
FROM 
    sys.sql_modules m
INNER JOIN 
    sys.objects o ON m.object_id = o.object_id
INNER JOIN 
    sys.schemas s ON o.schema_id = s.schema_id
WHERE 
    m.definition LIKE '%cm.ProductTypeId%'
 --AND m.definition LIKE '@ApproveStatusId'
    AND o.type = 'P'  -- 'P' stands for stored procedures
ORDER BY 
    s.name, o.name;