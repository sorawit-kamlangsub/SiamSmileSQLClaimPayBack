SELECT 
v.App_id
,v.แผนประกัน					ProductCategory
,v.จังหวัด						Province
,v.Code
,v.DateNotice
,v.ชื่อลูกค้า					Customer
,v.เริ่มคุ้มครอง					StartCoverDate
,v.ClaimType
,v.ClaimAdmitType
,v.ClaimType_id
,v.ClaimAdmitType_id
,v.Hospital
,v.Hospital_id
,v.ICD10_1
,v.ICD10
,v.IsContinue
,v.ContinueFromClaim_id
,v.Date_In
,v.Date_Out
,v.IPDExcept
,v.net
,v.Cover
,v.UnCover
,v.Pay
,v.UnPay
,v.Discount
,v.Compensate_net
,v.Compensate_Include
,v.Compensate_Remain
,v.Pay_Total
,v.UnPay_Total
,v.IsIncludeCompensateAll
,v.Compensate_Discount
,v.Remark
,v.ClaimHeaderGroup_id
,v.IPDCount
,v.ICUCount
,v.DateHappen
,v.IsPayCenter
,v.DCR
,v.BranchID
,v.IDCard
,v.DiscountSS
,v.PaySS_Total
,v.PaySS						
,x.BillingRequestGroupCode
,x.BillingRequestItemCode
FROM  [SSS].[dbo].[rpt_ClaimHeaderGroupDetail] v 
	LEFT JOIN [ClaimPayBack].[dbo].BillingExport x
		ON v.Code = x.ClaimCode
WHERE v.Code = 'CL6212019177'
	AND x.BillingRequestGroupCode = 'BQGPH19H6809005'