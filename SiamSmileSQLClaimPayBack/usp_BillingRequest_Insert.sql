USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_Insert]    Script Date: 16/10/2568 10:37:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Napaporn Saarnwong
-- Create date: 2022-10-31  09:05
--	Updated date: 2023-02-08 Add input data (@BillingDateTo)
--				  2025-10-16 Add Parameter @CreatedDateFrom @CreatedDateTo Sorawit
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequest_Insert]
	@CreatedByUserId	INT				--CreatedByUserId and UpdatedByUserId
	,@BillingDateTo		DATE 
	,@CreatedDateFrom	DATE
	,@CreatedDateTo		DATE

AS
BEGIN
	SET NOCOUNT ON;

--EXECUTE  [dbo].[usp_BillingRequest_Insert_V1] @CreatedByUserId;


EXECUTE  [dbo].[usp_BillingRequest_Insert_V3] @CreatedByUserId, @BillingDateTo, @CreatedDateFrom, @CreatedDateTo;



END;

