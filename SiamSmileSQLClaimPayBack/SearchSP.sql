USE ClaimPayBack

SELECT 
    o.name AS [ProcedureName]
    ,o.schema_id
    ,s.name AS [SchemaName]   
    ,CAST(m.definition AS NVARCHAR(MAX)) AS [Definition]
FROM 
    sys.sql_modules m
INNER JOIN 
    sys.objects o ON m.object_id = o.object_id
INNER JOIN 
    sys.schemas s ON o.schema_id = s.schema_id
WHERE 1=1
    AND m.definition LIKE '%BillingRequestResultDetail%' 
    AND o.type = 'P'  -- 'P' stands for stored procedures
ORDER BY 
    s.name, o.name;

-----------------------------------------------------------------------------

--SELECT 
--    s.name AS SchemaName,
--    p.name AS ProcedureName,
--    ep.value AS [Description],
--    LEFT(m.definition, 255) AS [SQLDefinition]
--FROM sys.procedures p
--INNER JOIN sys.schemas s 
--    ON p.schema_id = s.schema_id
--LEFT JOIN sys.extended_properties ep 
--    ON ep.major_id = p.object_id 
--    AND ep.minor_id = 0
--    AND ep.name = 'MS_Description'
--LEFT JOIN sys.sql_modules m 
--    ON p.object_id = m.object_id
--WHERE 
--    (s.name = 'Claim' AND p.name = 'usp_ClaimPayBackDetail_InsertV4')
--    OR (s.name = 'dbo' AND p.name IN (
--        'usp_ClaimHeaderGroupValidateAmountPay_Select',
--        'usp_ClaimPayBackReportNonClaimCompensate_Select',
--        'usp_ClaimPayBackTransferNonClaimCompensateReport_Select',
--        'usp_OrganizeInfo_Select'
--    ))
--ORDER BY s.name, p.name;