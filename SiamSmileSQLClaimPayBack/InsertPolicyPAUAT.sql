USE [SSSPA]
GO


DECLARE @D DATETIME2 = GETDATE();

/*PN */
  DECLARE @CodeCategory VARCHAR(20) = 'PN';
  DECLARE @Result NVARCHAR(250);

  EXECUTE [SSSPA].[dbo].[SP_GenerateCode]
  @CodeCategory
  ,@Result OUTPUT
 
INSERT INTO [SSSPA].[dbo].[DB_CustomerPolicy] 
(
    [Code],
    [App_id],
    [PolicyType_id],
    [Detail],
    [BranchReceiveDate],
    [Remark],
    [CreatedBy_id],
    [CreatedDate],
    [ReceiveDate],
    [DocumentStatus_id],
    [CheckedBy_id],
    [CheckedDate],
    [UpdatedByCode],
    [UpdatedDate]
)
VALUES 
(
    @Result,                        -- Code
    '60202608',                     -- App_id
    '9601',                         -- PolicyType_id
    '000-26-11-PAA-12573',          -- Detail
    NULL,                           -- BranchReceiveDate
    NULL,                           -- Remark
    '00000',                        -- CreatedBy_id
    @D,                             -- CreatedDate
    NULL,                           -- ReceiveDate
    NULL,                           -- DocumentStatus_id
    NULL,                           -- CheckedBy_id
    NULL,                           -- CheckedDate
    '00000',                        -- UpdatedByCode
    @D                              -- UpdatedDate
);