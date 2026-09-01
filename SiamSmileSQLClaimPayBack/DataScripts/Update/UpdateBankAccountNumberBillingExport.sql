USE [ClaimPayBack]
GO
	
DECLARE @D2	DATETIME2(7);

/* Setup Data*/
DECLARE @BillingRequestGroupCode NVARCHAR(50) = 'BQGPA04B6906002',
		@BillingBankCode NVARCHAR(50) = N'BB1';	

	SET @D2 = GETDATE();
BEGIN TRY
	BEGIN TRANSACTION

	SELECT m.*
	--UPDATE m SET m.BankAccountNumber = bank.BankAccountNumber
	--		,m.BillingBankId = bank.BillingBankId
	FROM dbo.BillingExport m
	CROSS JOIN dbo.BillingBank bank
	WHERE m.BillingRequestGroupCode = @BillingRequestGroupCode
	AND bank.BillingBankCode = @BillingBankCode

	COMMIT TRANSACTION
END TRY
BEGIN CATCH

	IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH

-----------------------------