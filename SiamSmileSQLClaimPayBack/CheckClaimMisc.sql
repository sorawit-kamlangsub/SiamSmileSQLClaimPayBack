USE [ClaimMiscellaneous]
GO 

SELECT 
	cm.ClaimHeaderGroupCode		�Ţ����
	,pg.ProductGroupDetail		���͡������Ե�ѳ
	,cm.ProductTypeId
	,cm.ProductGroupId
	,cms.ClaimMiscStatusName    ʶҹк�
	,cm.ClaimAmount				�ʹ�ҧ���
	,cph.SumPaymentAmount		�ʹ�Թ�͹������
	,cph.UpdatedDate			�ѹ����͹�Թ
	,cp.Amount					�ʹ�͹�Թ��������� 
	,cm.CreatedByUserId
	,cm.ClaimMiscCode
INTO #temp
FROM misc.ClaimMisc cm
	LEFT JOIN misc.ClaimMiscPaymentHeader cph
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
	INNER JOIN misc.ClaimMiscStatus cms
		ON cm.ClaimMiscStatusId = cms.ClaimMiscStatusId
	LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pg 
		ON cm.ProductGroupId = pg.ProductGroup_ID
WHERE cm.IsActive = 1
	AND cph.IsActive = 1
	AND cm.ClaimHeaderGroupCode IS NOT NULL
	AND cm.ClaimMiscStatusId = 3

SELECT * FROM #temp;

SELECT 
	cpb.ClaimPayBackId
	,cpbd.ClaimGroupCode
	,cpbx.ClaimCode
	,cpb.CreatedDate
FROM [ClaimPayBack].[dbo].[ClaimPayBack] cpb
	INNER JOIN [ClaimPayBack].[dbo].[ClaimPayBackDetail] cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	INNER JOIN [ClaimPayBack].[dbo].[ClaimPayBackXClaim] cpbx
		ON cpbd.ClaimPayBackDetailId = cpbx.ClaimPayBackDetailId
	INNER JOIN #temp tmp 
		ON cpbd.ClaimGroupCode = tmp.�Ţ����
WHERE cpbd.IsActive = 1


IF OBJECT_ID('tempdb..#temp') IS NOT NULL  DROP TABLE #temp;	