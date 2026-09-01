USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestResultImportGroup_Select]    Script Date: 15/7/2569 11:34:19 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sorawit kamlangsub
-- Create date: 2026-07-04 9:26
-- Update date: 2026-07-15 10:00 Reomve filter brd.BillingRequestItemCode Is Null 
--				in #temp
-- Description:	Output Out2 Billing Import 
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequestResultImportGroup_Select]
	-- Add the parameters for the stored procedure here
	@TmpCode NVARCHAR(MAX),
	@BillingRequestGroupCode NVARCHAR(MAX)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @_TmpCode VARCHAR(20) = @TmpCode; 
	DECLARE @_BillingRequestGroupCode NVARCHAR(MAX) = @BillingRequestGroupCode; 

	SELECT
	*
	INTO #tmpTmplist
	FROM dbo.func_SplitStringToTable(@TmpCode,',')	
	
	SELECT
	*
	INTO #tmplist
	FROM dbo.func_SplitStringToTable(@_BillingRequestGroupCode,',')

	SELECT DISTINCT
	 bg.BillingRequestGroupCode
	 INTO #temp
	FROM dbo.BillingRequestItem bi 
     LEFT JOIN dbo.BillingRequestGroup bg
        ON bg.BillingRequestGroupId = bi.BillingRequestGroupId
	 LEFT JOIN dbo.BillingRequestResultImport bri
	  ON bi.BillingRequestItemCode = bri.BillingRequestItemCode
	 LEFT JOIN dbo.BillingRequestResultDetail brd
	  ON brd.BillingRequestItemCode = bi.BillingRequestItemCode
	 LEFT JOIN #tmplist t
	  ON t.Element = bg.BillingRequestGroupCode
	WHERE	
	(   
		 EXISTS 
		 (
			SELECT 1 
			FROM #tmpTmplist t
			WHERE t.Element = bri.tmpCode
		 )
			AND @_BillingRequestGroupCode IS NULL
		 )
		OR (
			@_TmpCode IS NULL 
			AND 
			EXISTS 
				(
					SELECT 1
					FROM #tmplist t
					WHERE t.Element = bg.BillingRequestGroupCode
				)
	 )
	 AND NOT EXISTS
	 (
		SELECT 1
		FROM dbo.TmpBillingReceiveResultHeader t
		WHERE t.BillingRequestGroupCode = bg.BillingRequestGroupCode
		AND t.IsActive = 1
		AND t.BillingReceiveStatusId IN (2,3)
	 )
	 AND (brd.DecisionStatusId IS NULL OR brd.DecisionStatusId <> 4)

	SELECT 
	 bg.BillingRequestGroupCode
	 ,i.BillingRequestItemCode
	 ,bg.BillingDate
	 ,bg.ItemCount
	 ,bg.TotalAmount
	 ,IIF(rj.BillingRequestItemCode IS NULL, i.AmountTotal, 0)    ApproveAmount              
	 ,rj.RejectedAmount
	 ,IIF(ISNULL(i.AmountTotal,0) - ISNULL(rj.RejectedAmount,0) <> ISNULL(i.AmountTotal,0) AND  ISNULL(i.AmountTotal,0) - ISNULL(rj.RejectedAmount,0) > 0,ISNULL(i.AmountTotal,0) - ISNULL(rj.RejectedAmount,0),0) SomeApproveAmount
	 ,IIF(rj.BillingRequestItemCode IS NULL, 1, 0) IsApprove
	 ,IIF(rj.BillingRequestItemCode IS NOT NULL AND ISNULL(i.AmountTotal,0) - ISNULL(rj.RejectedAmount,0) = 0, 1, 0) IsReject
	 ,IIF(ISNULL(i.AmountTotal,0) - ISNULL(rj.RejectedAmount,0) <> ISNULL(i.AmountTotal,0) AND  ISNULL(i.AmountTotal,0) - ISNULL(rj.RejectedAmount,0) > 0,1,0) IsSomeApprove
	INTO #rawData
	FROM dbo.BillingRequestItem  i
	 LEFT JOIN dbo.BillingRequestGroup bg
		ON bg.BillingRequestGroupId = i.BillingRequestGroupId
	 INNER JOIN #temp t
		ON t.BillingRequestGroupCode = bg.BillingRequestGroupCode 
	 LEFT JOIN 
	 (
		SELECT 
		 BillingRequestItemCode
		 ,RejectedAmount
		 ,IsActive 
		FROM dbo.BillingRequestResultImport 
		WHERE IsActive = 1
	 ) rj
		ON rj.BillingRequestItemCode = i.BillingRequestItemCode

	SELECT 
	 bg.BillingRequestGroupCode
	 ,ic.ItemCount				ItemCount
	 ,BillingDate								
	 ,ta.TotalAmount
	 ,SUM(ApproveAmount)        ApproveAmount
	 ,SUM(CASE WHEN IsReject = 1 THEN RejectedAmount ELSE 0 END)       RejectedAmount
	 ,SUM(SomeApproveAmount)    SomeRejectApproveAmount
	 ,SUM(IsApprove)            ItemApproveCount
	 ,SUM(IsReject)             ItemRejectCount
	 ,SUM(IsSomeApprove)        ItemSomeApproveCount
	 ,SUM(CASE WHEN IsSomeApprove = 1 THEN RejectedAmount ELSE 0 END) SomeApproveAmount
	FROM #rawData
	CROSS JOIN
	(
		SELECT STUFF((
			SELECT DISTINCT ',' + BillingRequestGroupCode
			FROM #rawData
			FOR XML PATH(''), TYPE
		).value('.', 'nvarchar(max)'),1,1,'') AS BillingRequestGroupCode
	) bg
	CROSS JOIN
	(
		SELECT
			SUM(ItemCount) AS ItemCount
		FROM (
			SELECT BillingRequestGroupCode,
				   MAX(ItemCount) AS ItemCount
			FROM #rawData
			GROUP BY BillingRequestGroupCode
		) ic
	) ic
	CROSS JOIN
	(
		SELECT
			SUM(TotalAmount) AS TotalAmount
		FROM (
			SELECT BillingRequestGroupCode,
				   MAX(TotalAmount) AS TotalAmount
			FROM #rawData
			GROUP BY BillingRequestGroupCode
		) t
	) ta
	GROUP BY bg.BillingRequestGroupCode
	,ta.TotalAmount
	,ic.ItemCount
	,BillingDate

	IF OBJECT_ID('tempdb..#temp') IS NOT NULL DROP TABLE #temp;
	IF OBJECT_ID('tempdb..#rawData') IS NOT NULL DROP TABLE #rawData;
    IF OBJECT_ID('tempdb..#tmplist') IS NOT NULL DROP TABLE #tmplist;
    IF OBJECT_ID('tempdb..#tmpTmplist') IS NOT NULL DROP TABLE #tmpTmplist;

	--Revert
	--DECLARE @BillingRequestGroupCode varchar;
	--DECLARE	@ItemCount int;
	--DECLARE @TotalAmount decimal;
	--DECLARE @ApproveAmount decimal;
	--DECLARE @ItemApproveCount int;
	--DECLARE @ItemRejectCount int;
	--DECLARE @ItemSomeApproveCount int;
	--DECLARE @BillingDate DATETIME2;
	--DECLARE @RejectedAmount decimal;
	--DECLARE @SomeApproveAmount decimal;
	--DECLARE @SomeRejectApproveAmount decimal;

	--SELECT @BillingRequestGroupCode	BillingRequestGroupCode
	--	,@BillingDate				BillingDate
	--	,@ItemCount					ItemCount
	--	,@TotalAmount				TotalAmount
	--	,@ApproveAmount				ApproveAmount
	--	,@RejectedAmount			RejectedAmount
	--	,@SomeApproveAmount			SomeApproveAmount
	--	,@ItemApproveCount			ItemApproveCount
	--	,@ItemRejectCount			ItemRejectCount
	--	,@ItemSomeApproveCount		ItemSomeApproveCount
	--	,@SomeRejectApproveAmount	SomeRejectApproveAmount
END
