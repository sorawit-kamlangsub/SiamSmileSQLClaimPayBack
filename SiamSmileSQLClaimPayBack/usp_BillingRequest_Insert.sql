USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_Insert]    Script Date: 10/10/2568 10:19:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Napaporn Saarnwong
-- Create date: 2022-10-31  09:05
--	Updated date: 2023-02-08 Add input data (@BillingDateTo)
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

