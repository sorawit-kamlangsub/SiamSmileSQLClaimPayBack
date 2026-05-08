		DECLARE @TmpCode VARCHAR(20) = 'TCB6905000230'
    
	SELECT	TmpBillingRequestResultId
			,TmpCode
			,BillingRequestItemCode
			,PaymentReferenceId
			,CoverAmount
			,UncoverAmount
			,UnCoverRemark
			,DecisionStatus
			,RejectResult
			,DecisionDate
			,EstimatePaymentDate
			,Remark
			,IsValid
			,ValidateResult
			,PaymentDate
			,AmountPayment
			,BankName
			,BankAccountName
			,BankAccountNumber
			,Remark3
	INTO	#TmpList
	FROM	dbo.TmpBillingRequestResult
	WHERE	TmpCode = @TmpCode;
  
  	SELECT	COUNT(TmpCode)
	FROM	#TmpList;
    
    SELECT	r.TmpBillingRequestResultId
				,r.TmpCode
				,r.BillingRequestItemCode
				,r.PaymentReferenceId
				,r.CoverAmount
				,r.UncoverAmount
				,r.UnCoverRemark
				,r.DecisionStatus
				,r.RejectResult
				,r.DecisionDate
				,r.EstimatePaymentDate
				,r.Remark
				,r.IsValid
        ,bd.UpdatedDate
				,CONCAT(	IIF(r.DecisionStatus IN (N'อนุมัติ', N'ปฏิเสธ') , '', N'สถานะไม่ถูกต้อง ')
							,IIF(c.BillingRequestItemCode IS NOT NULL, N'ซ้ำกันในไฟล์ ' , '')
							,IIF(bd.BillingRequestItemCode IS NOT NULL, N'ข้อมูลนี้นำส่งแล้ว ', '')
							,IIF(bi.BillingRequestItemCode IS NULL, N'ไม่พบรหัสนี้ในระบบ', '')
						) AS ValidateResult
		
		FROM	dbo.TmpBillingRequestResult AS r
				LEFT JOIN 
					(	SELECT	BillingRequestItemCode
						FROM	#TmpList AS r
						GROUP BY BillingRequestItemCode
						HAVING COUNT(TmpBillingRequestResultId) > 1
					) AS c
					ON r.BillingRequestItemCode = c.BillingRequestItemCode
				LEFT JOIN dbo.BillingRequestResultDetail AS bd
					ON r.BillingRequestItemCode = bd.BillingRequestItemCode
				LEFT JOIN 
					(	SELECT	BillingRequestItemId
								,BillingRequestItemCode
								,BillingRequestGroupId
								,ClaimHeaderGroupImportDetailId
								,PaySS_Total
								,CoverAmount
								,AmountTotal
								,IsActive
								,CreatedDate
								,CreatedByUserId
								,UpdatedDate
								,UpdatedByUserId
						FROM	dbo.BillingRequestItem
						WHERE	IsActive = 1
					) AS bi
					ON r.BillingRequestItemCode = bi.BillingRequestItemCode
        WHERE r.TmpCode = @TmpCode;
        
        
        
   		SELECT	TmpBillingRequestResultId
				,TmpCode
				,BillingRequestItemCode
				,PaymentDate
				,AmountPayment
				,BankName
				,BankAccountName
				,BankAccountNumber
				,Remark3
				,ValidateResult
				,COUNT(TmpBillingRequestResultId) OVER ( ) AS TotalCount
		FROM 	dbo.TmpBillingRequestResult
		WHERE	TmpCode = @TmpCode     
    
    
    IF OBJECT_ID('tempdb..#TmpList') IS NOT NULL  DROP TABLE #TmpList;