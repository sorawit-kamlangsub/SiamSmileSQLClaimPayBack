USE [ClaimMiscellaneous]
GO

DECLARE @ClaimHeaderGroupCode NVARCHAR(50) = 'CHSPO88868100008';

SELECT 
	cm.ClaimHeaderGroupCode
	,cm.ClaimMiscStatusId
	,cm.ClaimAmount
	,cph.SumPaymentAmount
	,cp.PaymentDate
	,cp.Amount
	,cp.PaymentDate
FROM misc.ClaimMisc cm
	INNER JOIN misc.ClaimMiscPaymentHeader cph
		ON cm.ClaimMiscId = cph.ClaimMiscId
	INNER JOIN misc.ClaimMiscPayment cp 
		ON cph.ClaimMiscPaymentHeaderId = cp.ClaimMiscPaymentHeaderId
WHERE cm.IsActive = 1
	AND cph.IsActive = 1
	AND cp.IsActive = 1
	AND cm.ClaimHeaderGroupCode = @ClaimHeaderGroupCode;