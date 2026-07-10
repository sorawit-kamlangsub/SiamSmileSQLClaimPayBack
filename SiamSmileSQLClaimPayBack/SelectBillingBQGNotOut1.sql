SELECT DISTINCT 
b.BillingRequestGroupCode 
,b.BillingDate
,bi.BillingRequestItemCode
,bi.AmountTotal
FROM [dbo].[BillingRequestGroup] b
LEFT JOIN [dbo].[BillingRequestItem] bi
	ON bi.BillingRequestGroupId = b.BillingRequestGroupId
 WHERE b.[BillingRequestGroupStatusId] = N'3' 
 AND b.[IsActive] = N'1' 
 AND b.[InsuranceCompanyId] = N'18' 
AND NOT EXISTS 
(
SELECT 1
FROM dbo.TmpBillingReceiveResultHeader t
WHERE t.IsActive = 1 AND t.BillingRequestGroupCode = b.BillingRequestGroupCode
)
ORDER BY b.BillingDate DESC