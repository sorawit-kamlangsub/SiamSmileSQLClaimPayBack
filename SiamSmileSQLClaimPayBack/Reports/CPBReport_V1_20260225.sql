DECLARE @StartDate DATE = '2025-01-01'
DECLARE @EndDate DATE = '2026-02-25'


SELECT
	cpbxc.ClaimCode
	,cpbd.ClaimOnLineCode
	,cpbd.ClaimGroupCode
	,b.BranchDetail
	,o.OrganizeDetail
	,cpbd.CreatedDate
	,cpt.TransferDate
	,cgt.ClaimGroupType
FROM ClaimPayBackDetail cpbd
	LEFT JOIN ClaimPayBack cpb
		ON cpbd.ClaimPayBackId = cpb.ClaimPayBackId
	LEFT JOIN ClaimPayBackXClaim cpbxc
		ON cpbxc.ClaimPayBackDetailId = cpbd.ClaimPayBackDetailId
	LEFT JOIN DataCenterV1.Address.Branch b
		ON b.Branch_ID = cpb.BranchId
	LEFT JOIN DataCenterV1.Organize.Organize o
		ON o.Organize_ID = cpbd.InsuranceCompanyId
	LEFT JOIN ClaimPayBackTransfer cpt
		ON cpt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
	LEFT JOIN ClaimGroupType cgt
		ON cgt.ClaimGroupTypeId = cpb.ClaimGroupTypeId
WHERE cpbd.IsActive = 1
AND (cpbd.CreatedDate >= @StartDate AND cpbd.CreatedDate < @EndDate)