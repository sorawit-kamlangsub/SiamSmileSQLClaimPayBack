USE [ClaimPayBack]
GO

DECLARE @D DATETIME2(7) = GETDATE()
,@UserId INT = 1;

SELECT DISTINCT
	cpbd.ClaimGroupCode
	,cpbxc.HospitalName
	,cpbxc.ClaimCode
	,cm.CustomerName
	,@D						SendDate
	,8						ClaimGroupTypeId
	,1						IsActive
	,@UserId				CreatedByUserId
	,@D						CreatedDate
	,@UserId				UpdatedByUserId
	,@D						UpdatedDate
FROM [dbo].[ClaimPayBackDetail] cpbd
INNER JOIN [dbo].[ClaimPayBack] cpb
	ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
INNER JOIN [dbo].[ClaimPayBackXClaim] cpbxc
	ON cpbxc.ClaimPayBackDetailId = cpbd.ClaimPayBackDetailId
INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
	ON cm.ClaimHeaderGroupCode = cpbd.ClaimGroupCode
WHERE cpbd.IsActive = 1
AND cpb.IsActive = 1
AND cpbxc.IsActive = 1
AND cm.IsActive = 1
AND
cpb.ClaimGroupTypeId = 8
