USE [ClaimMiscellaneous]
GO

DECLARE @ClaimHeaderGroupCode NVARCHAR(50) = 'CHSPO88868100008';

SELECT 
	cm.ClaimHeaderGroupCode		เลขที่บส
	,cms.ClaimMiscStatusName    สถานะบส
	,cm.ClaimAmount				ยอดวางบิล
	,cph.SumPaymentAmount		ยอดเงินโอนทั้งหมด
	,cph.UpdatedDate			วันที่โอนเงิน
	,cp.Amount					ยอดโอนเงินรวมทั้งหมด 
FROM misc.ClaimMisc cm
	INNER JOIN misc.ClaimMiscPaymentHeader cph
		ON cm.ClaimMiscId = cph.ClaimMiscId
	INNER JOIN 
	(
		SELECT 
			SUM(Amount)	Amount
			,ClaimMiscPaymentHeaderId
		FROM misc.ClaimMiscPayment
		WHERE IsActive = 1
		GROUP BY ClaimMiscPaymentHeaderId
	)cp
		ON cph.ClaimMiscPaymentHeaderId = cp.ClaimMiscPaymentHeaderId
	LEFT JOIN misc.ClaimMiscStatus cms
		ON cm.ClaimMiscStatusId = cms.ClaimMiscStatusId
WHERE cm.IsActive = 1
	AND cph.IsActive = 1 

	AND cm.ClaimHeaderGroupCode = @ClaimHeaderGroupCode;


SELECT 
	cpb.ClaimPayBackId
	,cpbd.ClaimGroupCode
	,cpbx.ClaimCode
FROM [ClaimPayBack].[dbo].[ClaimPayBack] cpb
	INNER JOIN [ClaimPayBack].[dbo].[ClaimPayBackDetail] cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	INNER JOIN [ClaimPayBack].[dbo].[ClaimPayBackXClaim] cpbx
		ON cpbd.ClaimPayBackDetailId = cpbx.ClaimPayBackDetailId
WHERE cpbd.ClaimGroupCode = @ClaimHeaderGroupCode;