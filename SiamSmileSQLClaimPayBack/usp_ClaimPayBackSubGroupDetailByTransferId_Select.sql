USE [ClaimPayBack]
GO

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

	--TEST
	--DECLARE @ClaimPayBackTransferId INT = 5301;
	--END Test
		
		DECLARE @ClaimPayBackSubGroupId INT;
		SELECT @ClaimPayBackSubGroupId = ClaimPayBackSubGroupId FROM [dbo].ClaimPayBackSubGroupDetail WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId

		SELECT DISTINCT
				cpbsg.ClaimPayBackSubGroupId  
				,cpbsg.ClaimPayBackSubGroupCode
				,cpbt.ClaimPayBackTransferCode
				,cpbt.ClaimPayBackTransferStatusId
				,cpbts.ClaimPayBackTransferStatus
				,cpbt.OutOfPocketStatus			ClaimPayBackOutOfPokectStatusId		
				,cpbops.OutOfPocketStatusName	ClaimPayBackOutOfPokectStatus
				,cgt.ClaimGroupType
				,cpbt.TransferDate
				,cpbt.Amount
				,cpbsgdt.ClaimPayBackTransferId
				,IIF(cpbsgdt.ClaimPayBackTransferId = @ClaimPayBackTransferId,CAST(1 AS BIT),CAST(0 AS BIT)) IsThisCpbt
				,cpbsg.IsPayTransfer
				,cpbsg.BillingTransferDate
			FROM [dbo].[ClaimPayBackSubGroupDetail] cpbsgdt
				INNER JOIN dbo.ClaimPayBackTransfer cpbt
					ON cpbt.ClaimPayBackTransferId = cpbsgdt.ClaimPayBackTransferId
				LEFT JOIN (
					SELECT 
					cgt.ClaimGroupTypeId
					,cgt.ClaimGroupType
					FROM ClaimGroupType cgt
					WHERE cgt.IsActive = 1
				)cgt
					ON cgt.ClaimGroupTypeId = cpbt.ClaimGroupTypeId
				LEFT JOIN (
					SELECT
						ClaimPayBackSubGroupId
						,ClaimPayBackSubGroupCode
						,ClaimPayBackTransferId
						,Amount
						,IsPayTransfer
						,BillingTransferDate
					FROM dbo.ClaimPayBackSubGroup
					WHERE IsActive = 1
						AND TransactionType = 2
				) cpbsg
					ON cpbsg.ClaimPayBackSubGroupId = cpbsgdt.ClaimPayBackSubGroupId
				LEFT JOIN ClaimPayBackTransferStatus cpbts
					ON cpbt.ClaimPayBackTransferStatusId = cpbts.ClaimPayBackTransferStatusId
				LEFT JOIN ClaimPayBackOutOfPocketStatus cpbops
					ON cpbt.OutOfPocketStatus = cpbops.OutOfPocketStatusId
			WHERE cpbsgdt.IsActive = 1
			AND cpbt.IsActive = 1
			AND cpbsgdt.ClaimPayBackSubGroupId = @ClaimPayBackSubGroupId
			ORDER BY IsThisCpbt DESC

END;