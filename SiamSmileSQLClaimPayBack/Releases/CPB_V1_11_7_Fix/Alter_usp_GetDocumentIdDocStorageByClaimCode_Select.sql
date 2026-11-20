USE [ClaimPayBack]
GO

/****** Object:  StoredProcedure [dbo].[usp_GetDocumentIdDocStorageByClaimCode_Select]    Script Date: 11/20/2026 10:25:17 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sorawit kamlangsub
-- Create date: 2026-11-14
/* 
   Update date: 
*/
-- Description:	For Get DocStorage Data By ClaimCode
-- =============================================
ALTER PROCEDURE [dbo].[usp_GetDocumentIdDocStorageByClaimCode_Select] 
/* Add the parameters for the stored procedure here
 comment if not receive parameter*/
	@ClaimCodes NVARCHAR(MAX)

AS
BEGIN
/*SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.*/
	SET NOCOUNT ON;
-----------------------------------

	/*
	ClaimAdmitTypeCode
	Code	CodeGroup_id	Detail
	4000	2000			Dead Claim ทั่วไป(D) (PH)
	4001	2000			Dead Claim อุบัติเหตุ(D) (PH)
	4005	4000			ชดเชย สูญเสียอวัยวะ
	4006	4000			เสียชีวิต อุบัติเหตุทั่วไป (PA)
	4006_2	4000			เสียชีวิต อุบัติเหตุ ฆาตกรรม - MC (PA)
	4007	4000			เสียชีวิต โรคทั่วไป (PA)
	4008	4000			ทุพพลภาพ (PA)
	5001	2000			สูญเสียอวัยวะ/ทุพพลภาพ (อุบัติเหตุทั่วไป) (PH)
	5002	2000			สูญเสียอวัยวะ/ทุพพลภาพ (อุบัติเหตุจักรยานยนต์) (PH)
	*/

	SELECT 
		coi.ApplicationCode	MainIndex
		,coi.ClaimCode
		,coi.ClaimAdmitTypeCode
		,doc.DocumentId
		,doc.DocumentTypeId	
		,doc.DocumentCode
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
	,'4005'
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

END
GO

