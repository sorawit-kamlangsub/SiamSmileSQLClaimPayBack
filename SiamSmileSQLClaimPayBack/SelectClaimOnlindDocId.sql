USE [ClaimPayBack]
GO

DECLARE @ClaimCodes NVARCHAR(MAX) = 'CLPA680800000570,CLPA690700000655';

/*
ClaimAdmitTypeCode
Code	CodeGroup_id	Detail
4000	2000			Dead Claim ทั่วไป(D) (PH)
4001	2000			Dead Claim อุบัติเหตุ(D) (PH)
4006	4000			เสียชีวิต อุบัติเหตุทั่วไป (PA)
4006_2	4000			เสียชีวิต อุบัติเหตุ ฆาตกรรม - MC (PA)
4007	4000			เสียชีวิต โรคทั่วไป (PA)
4008	4000			ทุพพลภาพ (PA)
5001	2000			สูญเสียอวัยวะ/ทุพพลภาพ (อุบัติเหตุทั่วไป) (PH)
5002	2000			สูญเสียอวัยวะ/ทุพพลภาพ (อุบัติเหตุจักรยานยนต์) (PH)
*/

SELECT 
 cid.ClaimHeaderGroupCode
 ,cid.ClaimCode
 ,cid.ClaimType
 ,doc.DocumentId
FROM [dbo].ClaimHeaderGroupImportDetail cid
INNER JOIN [ClaimOnlineV2].[dbo].ClaimOnlineItem coi
	ON cid.ClaimCode = coi.ClaimCode
INNER JOIN [ClaimOnlineV2].[dbo].[Document] doc
	ON coi.ClaimOnLineItemId = doc.ClaimOnLineItemId
INNER JOIN [dbo].func_SplitStringToTable(@ClaimCodes,',') tmp
	ON cid.ClaimCode = tmp.Element
WHERE cid.IsActive = 1
AND coi.IsActive = 1
AND doc.IsActive = 1
AND coi.ClaimAdmitTypeCode IN (
'4000'	
,'4001'	
,'4006'	
,'4006_2'	
,'4007'	
,'4008'	
,'5001'	
,'5002'	
)

-- PH
--SELECT TOP 1000 * FROM [dbo].[SM_Code] WHERE [CodeGroup_id] LIKE N'%4000%'
--PA
--SELECT TOP 1000 * FROM [dbo].[MT_ClaimAdmitType]
