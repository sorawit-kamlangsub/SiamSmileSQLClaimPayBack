CREATE TABLE [dbo].[BillingRequestGroupSFTPEncryption] (
  [Id] int  IDENTITY(1,1) NOT NULL,
  [BillingRequestGroup] nvarchar(100) COLLATE Thai_100_CI_AI  NULL,
  [ZipFileName] nvarchar(100) COLLATE Thai_100_CI_AI  NULL,
  [PathFile] nvarchar(255) COLLATE Thai_100_CI_AI  NULL,
  [OrganizationId] int  NULL,
  [OrganizationName] nvarchar(255) COLLATE Thai_100_CI_AI  NULL,
  [BillingDate] date  NULL,
  [IsActive] bit  NULL,
  [CreatedByUserId] int  NULL,
  [CreatedDate] datetime2(7)  NULL,
  [UpdatedByUserId] int  NULL,
  [UpdatedDate] datetime2(7)  NULL,
  CONSTRAINT [PK_BillingRequestGroupSFTPEncryption] PRIMARY KEY CLUSTERED ([Id])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)  
ON [PRIMARY]
)  
ON [PRIMARY]
GO

ALTER TABLE [dbo].[BillingRequestGroupSFTPEncryption] SET (LOCK_ESCALATION = TABLE)
GO

EXEC sp_addextendedproperty
'MS_Description', N'ชื่อเอกสาร ต้นฉบับ',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'ZipFileName'
GO

EXEC sp_addextendedproperty
'MS_Description', N'path เก็บเอกสาร',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'PathFile'
GO

EXEC sp_addextendedproperty
'MS_Description', N'รหัส บ.ประกัน',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'OrganizationId'
GO

EXEC sp_addextendedproperty
'MS_Description', N'ชื่อ บ.ประกัน',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'OrganizationName'
GO

EXEC sp_addextendedproperty
'MS_Description', N'วันที่วางบิล',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'BillingDate'
GO

EXEC sp_addextendedproperty
'MS_Description', N'สถานะ',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'IsActive'
GO

EXEC sp_addextendedproperty
'MS_Description', N'รหัสผู้สร้าง',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'CreatedByUserId'
GO

EXEC sp_addextendedproperty
'MS_Description', N'วันที่สร้าง',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'CreatedDate'
GO

EXEC sp_addextendedproperty
'MS_Description', N'ผู้แก้ไข',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'UpdatedByUserId'
GO

EXEC sp_addextendedproperty
'MS_Description', N'วันที่แก้ไข',
'SCHEMA', N'dbo',
'TABLE', N'BillingRequestGroupSFTPEncryption',
'COLUMN', N'UpdatedDate'