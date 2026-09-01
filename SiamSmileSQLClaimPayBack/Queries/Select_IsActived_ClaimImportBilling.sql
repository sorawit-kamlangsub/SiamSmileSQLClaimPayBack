USE [ClaimPayBack]
GO

--SELECT
-- t.ClaimHeaderGroupCode
-- ,1 ItemCount
-- ,t.ClaimNo
-- ,bi.BillingRequestItemCode
-- ,bg.BillingRequestGroupCode
-- ,bg.BillingDate
-- ,bg.TotalAmount
--FROM DataImportExcel.dbo.[20260827_1401_ImportBOHO] t
--LEFT JOIN 
--(
--	SELECT 
--	 ClaimHeaderGroupCode
--	 ,ClaimHeaderGroupImportId
--	FROM dbo.ClaimHeaderGroupImportDetail
--	WHERE IsActive = 0
--) id
--	ON t.ClaimHeaderGroupCode = id.ClaimHeaderGroupCode
--LEFT JOIN 
--(
--	SELECT 
--	 BillingRequestGroupId
--	 ,BillingRequestItemCode
--	 ,ClaimHeaderGroupImportDetailId
--	FROM dbo.BillingRequestItem
--	WHERE IsActive = 1
--) bi
--	ON id.ClaimHeaderGroupImportId = bi.ClaimHeaderGroupImportDetailId
--LEFT JOIN dbo.BillingRequestGroup bg
--	ON bi.BillingRequestGroupId = bg.BillingRequestGroupId
--ORDER BY t.ClaimHeaderGroupCode DESC;

SELECT
rs.BillingRequestGroupCode
 ,rs.BillingDate
,SUM(bi.PaySS_Total) AmountTotal
FROM
(
SELECT
bg.BillingRequestGroupCode
,bg.BillingRequestGroupId
 ,bg.BillingDate
 ,bg.TotalAmount
FROM DataImportExcel.dbo.[20260827_1401_ImportBOHO] t
LEFT JOIN 
(
	SELECT 
	 ClaimHeaderGroupCode
	 ,ClaimHeaderGroupImportId
	FROM dbo.ClaimHeaderGroupImportDetail
	WHERE IsActive = 1
) id
	ON t.ClaimHeaderGroupCode = id.ClaimHeaderGroupCode
LEFT JOIN 
(
	SELECT 
	 BillingRequestGroupId
	 ,BillingRequestItemCode
	 ,ClaimHeaderGroupImportDetailId
	 ,PaySS_Total
	FROM dbo.BillingRequestItem
	WHERE IsActive = 1
) bi
	ON id.ClaimHeaderGroupImportId = bi.ClaimHeaderGroupImportDetailId
LEFT JOIN dbo.BillingRequestGroup bg
	ON bi.BillingRequestGroupId = bg.BillingRequestGroupId

GROUP BY
bg.BillingRequestGroupCode
,bg.BillingRequestGroupId
 ,bg.BillingDate
 ,bg.TotalAmount

) rs
INNER JOIN dbo.BillingRequestItem bi
	ON rs.BillingRequestGroupId = bi.BillingRequestGroupId
GROUP BY
rs.BillingRequestGroupCode
,rs.BillingRequestGroupId
 ,rs.BillingDate
 ,rs.TotalAmount
;