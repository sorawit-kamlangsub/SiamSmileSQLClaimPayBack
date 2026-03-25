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

		SELECT
				cpbsg.ClaimPayBackSubGroupId  
				,cpbsg.ClaimPayBackSubGroupCode
				,cpbt.ClaimPayBackTransferCode
				,cpbt.ClaimPayBackTransferStatusId
				,cpbts.ClaimPayBackTransferStatus
				,cpbt.OutOfPocketStatus
				,cpbops.OutOfPocketStatusName
				,cgt.ClaimGroupType
				,cpbt.TransferDate
				,cpbsg.Amount
				,cpbsg.ClaimPayBackTransferId
				,IIF(cpbsg.ClaimPayBackTransferId = @ClaimPayBackTransferId,1,0) IsThisCpbt
				,cpbsg.IsPayTransfer
				,cpbsg.BillingTransferDate
			FROM [dbo].[ClaimPayBackTransfer] cpbt
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
					ON cpbsg.ClaimPayBackTransferId = cpbt.ClaimPayBackTransferId
				LEFT JOIN ClaimPayBackTransferStatus cpbts
					ON cpbt.ClaimPayBackTransferStatusId = cpbts.ClaimPayBackTransferStatusId
				LEFT JOIN ClaimPayBackOutOfPocketStatus cpbops
					ON cpbt.OutOfPocketStatus = cpbops.OutOfPocketStatusId
			WHERE cpbt.ClaimPayBackTransferId = @ClaimPayBackTransferId
			ORDER BY IsThisCpbt DESC

END;
