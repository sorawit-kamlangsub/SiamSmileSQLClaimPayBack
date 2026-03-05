USE [ClaimPayBack]
GO

DECLARE 
    @NewBillingDate        DATE = '2026-03-05',
    @UpdatedByUserId       INT  = 6772;

DECLARE 
    @D2        DATETIME2 = SYSDATETIME(),
    @UserId    INT       = @UpdatedByUserId;

------------------------------------------------
-- 1) เตรียม List ของ BillingRequestGroupCode
------------------------------------------------
DECLARE @GroupCodes TABLE (
    RowNo INT IDENTITY(1,1),
    BillingRequestGroupCode NVARCHAR(50)
);

INSERT INTO @GroupCodes (BillingRequestGroupCode)
VALUES 
('BQGMP04B6900026'),
('BQGMP04B6900027')
;

------------------------------------------------
-- 2) Loop ทีละ Code
------------------------------------------------
DECLARE 
    @i INT = 1,
    @max INT,
    @BillingRequestGroupCode NVARCHAR(50),
    @BillingRequestGroupId INT,
    @ClaimHeaderGroupImportId INT;

SELECT @max = COUNT(*) FROM @GroupCodes;

WHILE @i <= @max
BEGIN
    SELECT @BillingRequestGroupCode = BillingRequestGroupCode
    FROM @GroupCodes
    WHERE RowNo = @i;

    ------------------------------------------------
    -- ClaimHeaderGroupImport
    ------------------------------------------------
    UPDATE m
    SET m.ClaimHeaderGroupImportStatusId = 2,
        m.BillingRequestGroupId          = NULL,
        m.UpdatedDate                    = @NewBillingDate,
        m.UpdatedByUserId                = @UserId,
        m.CreatedDate                    = @NewBillingDate,
        m.BillingDate                    = @NewBillingDate
    FROM dbo.ClaimHeaderGroupImport m
    INNER JOIN dbo.BillingRequestGroup bg
        ON bg.BillingRequestGroupId = m.BillingRequestGroupId
    WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

    ------------------------------------------------
    -- BillingRequestGroupId
    ------------------------------------------------
    SELECT @BillingRequestGroupId = bg.BillingRequestGroupId
    FROM dbo.BillingRequestGroup bg
    WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

    ------------------------------------------------
    -- ClaimHeaderGroupImportId
    ------------------------------------------------
    SELECT @ClaimHeaderGroupImportId = h.ClaimHeaderGroupImportId
    FROM dbo.ClaimHeaderGroupImport h
    INNER JOIN dbo.BillingRequestGroup bg
        ON bg.BillingRequestGroupId = h.BillingRequestGroupId
    WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

    ------------------------------------------------
    -- Deactivate BillingRequestGroup
    ------------------------------------------------
    UPDATE bg
    SET bg.IsActive = 0
    FROM dbo.BillingRequestGroup bg
    WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

    ------------------------------------------------
    -- Deactivate BillingRequestItem
    ------------------------------------------------
    UPDATE bi
    SET bi.IsActive = 0
    FROM dbo.BillingRequestItem bi
    WHERE bi.BillingRequestGroupId = @BillingRequestGroupId;

    --Insert ClaimHeaderGroupImportCancel
    ------------------------------------------------
    --INSERT INTO [dbo].[ClaimHeaderGroupImportCancel]
    --      ([ClaimHeaderGroupImportId]
    --      ,[CancelDetail]
    --      ,[IsActive]
    --      ,[CreatedByUserId]
    --      ,[CreatedDate])
    --SELECT 
    --	ci.ClaimHeaderGroupImportId	  ClaimHeaderGroupImportId
    --	,'ยกเลิก Generate Group โดยระบบ' CancelDetail
    --	,1							  IsActive
    --	,@UserId					  CreatedByUserId
    --	,@D2						  CreatedDate
    --FROM dbo.ClaimHeaderGroupImport ci
    --WHERE ci.ClaimHeaderGroupImportId = @ClaimHeaderGroupImportId;


    SET @i += 1;
END;
