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
	--DECLARE @ClaimPayBackTransferId INT = 4180;
	--END Test

	DECLARE @Tmp TABLE
	(
		ClaimPayBackSubGroupId INT
		,ClaimPayBackSubGroupCode VARCHAR(MAX)
		,ClaimPayBackTransferCode VARCHAR(MAX)
		,ClaimPayBackTransferStatusId INT
		,ClaimGroupType NVARCHAR(MAX)
		,TransferDate DATETIME2
		,Amount DECIMAL(16,2)
		,ClaimPayBackTransferId INT
		,IsThisCpbt BIT
	);

	DECLARE @IsLimitAmount BIT = 0;
	DECLARE @OutOfPocketAmountLimit  DECIMAL(16,2);
	DECLARE @ResultOutOfPocketAmountLimit  DECIMAL(16,2);
	SELECT @OutOfPocketAmountLimit = ValueNumber FROM dbo.ProgramConfig WHERE ParameterName = 'OutOfPocketAmountLimit'
	SELECT @ResultOutOfPocketAmountLimit = SUM(Amount) FROM ClaimPayBackSubGroupDetail WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId 

	IF @ResultOutOfPocketAmountLimit > @OutOfPocketAmountLimit
	BEGIN
		SET @IsLimitAmount = 1;
	END

	DECLARE @ClaimPayBackSubGroupId INT;
	SELECT @ClaimPayBackSubGroupId = ClaimPayBackSubGroupId FROM [dbo].ClaimPayBackSubGroupDetail WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId

	IF @IsLimitAmount = 0
	BEGIN
		INSERT INTO @Tmp
		(
			ClaimPayBackSubGroupId
			,ClaimPayBackSubGroupCode
			,ClaimPayBackTransferCode
			,ClaimPayBackTransferStatusId
			,ClaimGroupType
			,TransferDate
			,Amount
			,ClaimPayBackTransferId
			,IsThisCpbt
		)
		SELECT
				cpbsgd.ClaimPayBackSubGroupId  
				,cpbsg.ClaimPayBackSubGroupCode
				,cpbt.ClaimPayBackTransferCode
				,cpbt.ClaimPayBackTransferStatusId
				,cgt.ClaimGroupType
				,cpbt.TransferDate
				,cpbt.Amount
				,cpbsgd.ClaimPayBackTransferId
				,IIF(cpbsgd.ClaimPayBackTransferId = @ClaimPayBackTransferId,1,0) IsThisCpbt
			FROM [dbo].ClaimPayBackSubGroupDetail cpbsgd
				LEFT JOIN (
						SELECT
							ClaimPayBackTransferCode
							,ClaimPayBackTransferId
							,ClaimPayBackTransferStatusId
							,ClaimGroupTypeId
							,TransferDate
							,Amount
						FROM [dbo].ClaimPayBackTransfer 	
						WHERE IsActive = 1
					) cpbt
						ON cpbt.ClaimPayBackTransferId = cpbsgd.ClaimPayBackTransferId
				LEFT JOIN (
					SELECT
						ClaimPayBackSubGroupId
						,ClaimPayBackSubGroupCode
						,Amount
					FROM dbo.ClaimPayBackSubGroup
					WHERE IsActive = 1
				) cpbsg
					ON cpbsg.ClaimPayBackSubGroupId = cpbsgd.ClaimPayBackSubGroupId
				LEFT JOIN (
					SELECT 
					cgt.ClaimGroupTypeId
					,cgt.ClaimGroupType
					FROM ClaimGroupType cgt
					WHERE cgt.IsActive = 1
				)cgt
					ON cgt.ClaimGroupTypeId = cpbt.ClaimGroupTypeId
			WHERE cpbsgd.ClaimPayBackSubGroupId = @ClaimPayBackSubGroupId
			GROUP BY cpbsgd.ClaimPayBackSubGroupId
					,cpbsg.ClaimPayBackSubGroupCode
					,cpbsgd.ClaimPayBackTransferId
					,cpbt.ClaimPayBackTransferStatusId
					,cgt.ClaimGroupType
					,cpbt.TransferDate
					,cpbt.ClaimPayBackTransferCode
					,cpbt.Amount
			ORDER BY IsThisCpbt DESC
	END
	ELSE
	BEGIN

		INSERT INTO @Tmp
		(
			ClaimPayBackSubGroupId
			,ClaimPayBackSubGroupCode
			,ClaimPayBackTransferCode
			,ClaimPayBackTransferStatusId
			,ClaimGroupType
			,TransferDate
			,Amount
			,ClaimPayBackTransferId
			,IsThisCpbt
		)
		SELECT
				cpbsg.ClaimPayBackSubGroupId  
				,cpbsg.ClaimPayBackSubGroupCode
				,cpbt.ClaimPayBackTransferCode
				,cpbt.ClaimPayBackTransferStatusId
				,cgt.ClaimGroupType
				,cpbt.TransferDate
				,cpbsg.Amount
				,cpbsg.ClaimPayBackTransferId
				,IIF(cpbsg.ClaimPayBackTransferId = @ClaimPayBackTransferId,1,0) IsThisCpbt
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
					FROM dbo.ClaimPayBackSubGroup
					WHERE IsActive = 1
				) cpbsg
					ON cpbsg.ClaimPayBackTransferId = cpbt.ClaimPayBackTransferId
			WHERE cpbt.ClaimPayBackTransferId = @ClaimPayBackTransferId
			ORDER BY IsThisCpbt DESC

	END

	SELECT * FROM @Tmp

END;