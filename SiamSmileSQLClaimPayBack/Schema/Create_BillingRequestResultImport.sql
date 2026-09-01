USE [ClaimPayBack]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BillingRequestResultImport](
	[ImportId] [int] IDENTITY(1,1) NOT NULL,
	[tmpCode] [varchar](50) NULL,
	[InsuranceId] [int] NULL,
	[BillingRequestItemCode] [varchar](50) NULL,
	[RejectedAmount] [decimal](16, 2) NULL,
	[RejectedRemark] [nvarchar](max) NULL,
	[CreatedByUserId] [int] NULL,
	[CreatedDate] [datetime2](7) NULL,
	[IsActive] [bit] NULL,
 CONSTRAINT [PK_BillingRequestResultImport] PRIMARY KEY CLUSTERED 
(
	[ImportId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'รหัสอ้างอิง' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'tmpCode'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'รหัส บริษัทประกัน' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'InsuranceId'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'เลขที่รายการวางบิล' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'BillingRequestItemCode'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ยอดเงินปฎิเสธ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'RejectedAmount'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'สาเหตุ ปฎิเสธ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'RejectedRemark'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ผู้สร้างรายการ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'CreatedByUserId'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'วันที่สร้างรายการ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'CreatedDate'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'สถานะรายการ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BillingRequestResultImport', @level2type=N'COLUMN',@level2name=N'IsActive'
GO

