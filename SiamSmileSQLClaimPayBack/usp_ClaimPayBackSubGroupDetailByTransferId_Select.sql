USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroupDetailByTransferId_Select]    Script Date: 4/2/2569 15:11:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Krekpon.D
-- Create date: 2026-01-31 11:14
-- Description:	เอาข้อมูลจาก CPBT มาหา ClaimPayBackSubGroupDetail
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackSubGroupDetailByTransferId_Select] 
	 --Add the parameters for the stored procedure here
	@ClaimPayBackTransferId INT 
	
AS
BEGIN
	SET NOCOUNT ON;

--DECLARE @ClaimPayBackTransferId INT = 4168;

	SELECT
		cpbsg.ClaimPayBackSubGroupId  
		,cpbsg.ClaimPayBackSubGroupCode
		,cpbt.ClaimPayBackTransferCode
		,cpbt.ClaimPayBackTransferStatusId
		,cgt.ClaimGroupType
		,cpbt.TransferDate
		,cpbsg.Amount
	FROM [dbo].ClaimPayBackTransfer cpbt
		LEFT JOIN (
			SELECT 
			cpbsgs.ClaimPayBackSubGroupId
			,cpbsgs.ClaimPayBackSubGroupCode
			,cpbsgs.ClaimPayBackTransferId
			,cpbsgs.Amount
			FROM ClaimPayBackSubGroup cpbsgs
			WHERE cpbsgs.IsActive = 1
		) cpbsg
			ON cpbt.ClaimPayBackTransferId = cpbsg.ClaimPayBackTransferId
		LEFT JOIN (
			SELECT 
			cgt.ClaimGroupTypeId
			,cgt.ClaimGroupType
			FROM ClaimGroupType cgt
			WHERE cgt.IsActive = 1
		)cgt
			ON cgt.ClaimGroupTypeId = cpbt.ClaimGroupTypeId
	WHERE cpbt.ClaimPayBackTransferId = @ClaimPayBackTransferId
			AND cpbt.IsActive = 1

END;