USE [ClaimPayBack]
GO

------- ClaimPayBackSubGroup --------

ALTER TABLE [dbo].[ClaimPayBackSubGroup] ADD [TransactionType] INT NULL
GO

EXEC sp_addextendedproperty
'MS_Description', N'ประเภทการทำรายการ 1 โอนเงิน, 2 สำรองเงิน',
'SCHEMA', N'dbo',
'TABLE', N'ClaimPayBackSubGroup',
'COLUMN', N'TransactionType'
GO

ALTER TABLE [dbo].[ClaimPayBackSubGroup] ADD [AccountConfigId] INT NULL
GO

EXEC sp_addextendedproperty
'MS_Description', N'เลขที่ บช. ปลายทาง',
'SCHEMA', N'dbo',
'TABLE', N'ClaimPayBackSubGroup',
'COLUMN', N'AccountConfigId'
GO

------- ClaimPayBackTransfer --------

ALTER TABLE [dbo].[ClaimPayBackTransfer] ADD [OutOfPocketStatus] INT NULL
GO

EXEC sp_addextendedproperty
'MS_Description', N'สถานะสำรองจ่าย',
'SCHEMA', N'dbo',
'TABLE', N'ClaimPayBackTransfer',
'COLUMN', N'OutOfPocketStatus'
GO

ALTER TABLE [dbo].[ClaimPayBackTransfer] ADD [OutOfPocketAmount] DECIMAL(16,2) NULL
GO

EXEC sp_addextendedproperty
'MS_Description', N'จำนวนเงินที่สำรองจ่าย',
'SCHEMA', N'dbo',
'TABLE', N'ClaimPayBackTransfer',
'COLUMN', N'OutOfPocketAmount'
GO