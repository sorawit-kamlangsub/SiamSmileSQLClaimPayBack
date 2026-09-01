-- =============================================
DECLARE @ProductGroupId    INT    = 3;
DECLARE @ClaimGroupTypeId   INT    = 3; 
DECLARE @ClaimHeaderGroupCode  VARCHAR(MAX) = 'TSAO-541-68110023-0';
-- =============================================

-- Set message 
DECLARE @AmountWarning     NVARCHAR(MAX) = N'ยอด บ.ส.ไม่เท่ากับยอดโอน'; 
DECLARE @PolicyWarning     NVARCHAR(MAX) = N'ไม่มีเลขที่กรมธรรม์';
DECLARE @PolicyStatusWarning   NVARCHAR(MAX) = N'ตรวจสอบสถานะกรมธรรม์'; 
DECLARE @ClaimHeaderGroupAmountWarning NVARCHAR(MAX) = N'ยอดเงินตาม บ.ส.ไม่ถูกต้อง';
DECLARE @ClaimHeaderPaymentWarning  NVARCHAR(MAX) = N'บ.ส.นี้อยู่ระหว่างดำเนินการโอนเงิน';
DECLARE @ClaimOnlineStatusWarning  NVARCHAR(MAX) = N'สถานะ ClaimOnline ยกเลิก';
DECLARE @InsuranceCompanyId    VARCHAR(20) = '100000000041';

-- Create temp table
SELECT DISTINCT Element
INTO #Tmp
FROM dbo.func_SplitStringToTable(@ClaimHeaderGroupCode,',');

CREATE TABLE #Tmplst
(
 ClaimHeaderGroupCode VARCHAR(30)
 ,TransferAmount   DECIMAL(16,2)
 ,Amount     DECIMAL(16,2)
 ,NPLAmount    DECIMAL(16,2)
 ,ClaimCode    VARCHAR(50)
 ,WarningMessage   NVARCHAR(MAX)
);

-- PH
IF @ProductGroupId = 2

 BEGIN

  INSERT INTO #Tmplst(
   ClaimHeaderGroupCode
   ,TransferAmount
   ,Amount
   ,NPLAmount 
   ,ClaimCode
   ,WarningMessage
  )
  SELECT 
   chg.code        ClaimHeaderGroupCode
   ,ISNULL(colPH.TotalAmount, 0)   TotalAmount
   ,cv.PaySS_Total       Amount
   ,ISNULL(nplds.NPLAmount, 0)    NPLAmount
   ,ch.Code        ClaimCode
   ,CASE 
    WHEN  ISNULL(cv.PaySS_Total, 0) = 0 THEN @ClaimHeaderGroupAmountWarning
    WHEN @ClaimGroupTypeId IN(2,6)               
     AND (
      (ISNULL(colPH.TotalAmount, 0) = 0 AND cv.PaySS_Total = 0) OR ISNULL(colPH.TotalAmount, 0) <> (cv.PaySS_Total + ISNULL(nplds.NPLAmount, 0))
     )        THEN @AmountWarning
   ELSE NULL END  AS WarningMessage
  FROM sss.dbo.DB_ClaimHeaderGroup chg
   INNER JOIN #Tmp ts
    ON chg.Code = ts.Element
   LEFT JOIN SSS.dbo.DB_ClaimHeaderGroupItem cgi 
    ON chg.Code = cgi.ClaimHeaderGroup_id
   LEFT JOIN sss.dbo.DB_ClaimHeader ch
    ON cgi.ClaimHeader_id = ch.Code
   LEFT JOIN sss.dbo.DB_ClaimVoucher cv
    ON cgi.ClaimHeader_id = cv.Code
   LEFT JOIN
   (
    SELECT
     co.ClaimOnLineCode
     ,co.ClaimOnLineId
     ,SUM(cg.TotalAmount) TotalAmount
    FROM ClaimOnlineV2.dbo.ClaimOnline co
     LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
      ON cg.ClaimOnLineId = co.ClaimOnLineId
    WHERE co.IsActive = 1  
     AND cg.IsActive = 1
     AND cg.PaymentStatusId = 4
    GROUP BY  co.ClaimOnLineCode, co.ClaimOnLineId
   ) colPH
    ON colPH.ClaimOnLineCode = ch.ClaimOnLineCode
   LEFT JOIN (
    SELECT 
     ClaimOnLineId
     ,SUM(npld.Amount) NPLAmount
    FROM ClaimOnlineV2.dbo.NPLHeader nplh
     INNER JOIN ClaimOnlineV2.dbo.NPLDetail npld
      ON nplh.NPLHeaderId = npld.NPLHeaderId
    WHERE nplh.IsActive = 1
     AND npld.IsActive = 1
    GROUP BY ClaimOnLineId
   )nplds
    ON nplds.ClaimOnLineId = colPH.ClaimOnLineId

   WHERE  chg.InsuranceCompany_id <> @InsuranceCompanyId    

 END

-- PA
ELSE IF @ProductGroupId = 3

 BEGIN
    
  INSERT INTO #Tmplst(
   ClaimHeaderGroupCode
   ,TransferAmount
   ,Amount
   ,NPLAmount
   ,ClaimCode
   ,WarningMessage
  )
  SELECT 
   chgPA.Code       ClaimHeaderGroupCode
   ,ISNULL(colPA.TotalAmount, 0)  TransferAmount
   ,ISNULL(chPA.PaySS_Total, 0)  Amount
   ,ISNULL(nplds.NPLAmount, 0)   NPLAmount
   ,chPA.Code       ClaimCode 
   ,(
    ISNULL(
     CASE 
      WHEN @ClaimGroupTypeId <> 4
       AND (ctmpPA.Code IS NULL AND ctm.App_id IS NULL)
       THEN @PolicyWarning + ' , '
     END, ''
    )
    +
    ISNULL(
     CASE 
      WHEN ctm.App_id IS NULL
       THEN @PolicyStatusWarning + ' , '
     END, ''
    )
    +
    ISNULL(
     CASE 
      WHEN ISNULL(chPA.PaySS_Total, 0) = 0
       THEN CONCAT(@ClaimHeaderGroupAmountWarning, ' , ')
      ELSE ''
     END, NULL
    )
    +
    ISNULL(
     CASE 
      WHEN @ClaimGroupTypeId IN (2,6)
       AND (
        ISNULL(colPA.TotalAmount, 0) <> (chPA.PaySS_Total + ISNULL(nplds.NPLAmount, 0))
       )
      THEN @AmountWarning + ' , ' 
      ELSE ''
     END, NULL
    )
   ) AS WarningMessage
    
  FROM SSSPA.dbo.DB_ClaimHeaderGroupItem cgiPA
   LEFT JOIN SSSPA.dbo.DB_ClaimHeaderGroup chgPA
    ON cgiPA.ClaimHeaderGroup_id = chgPA.Code
   INNER JOIN #Tmp ts
    ON chgPA.Code = ts.Element
   LEFT JOIN SSSPA.dbo.DB_ClaimHeader chPA
    ON cgiPA.ClaimHeader_id = chPA.Code 
   LEFT JOIN (
    SELECT *
    FROM SSSPA.dbo.DB_CustomerDetail
    WHERE IsActive = 1
   ) ctmdPA
    ON chPA.CustomerDetail_id = ctmdPA.Code
   LEFT JOIN (
    SELECT * 
    FROM SSSPA.dbo.DB_CustomerPolicy
    WHERE PolicyType_id <> '9605'
   ) ctmpPA
    ON ctmdPA.Application_id = ctmpPA.App_id 
   LEFT JOIN (
    SELECT *
    FROM SSSPA.dbo.DB_Customer
    WHERE IsActive = 1
     AND Status_id = '3040' 
   )ctm
    ON ctmdPA.Application_id = ctm.App_id
   LEFT JOIN
   (
    SELECT  
     co.ClaimOnLineCode 
     ,co.ClaimOnLineId
     ,SUM(cg.TotalAmount)    TotalAmount
    FROM ClaimOnlineV2.dbo.ClaimOnline co
     LEFT JOIN (
      SELECT 
       ClaimOnLineId
       ,IsActive
       ,PaymentStatusId
       ,SUM(ISNULL(TotalAmount, 0)) TotalAmount
      FROM ClaimOnlineV2.dbo.ClaimPayGroup
      GROUP BY ClaimOnLineId
       ,IsActive
       ,PaymentStatusId
     )cg
      ON cg.ClaimOnLineId = co.ClaimOnLineId
    WHERE co.IsActive = 1
     AND cg.IsActive = 1  
     AND cg.PaymentStatusId = 4
    GROUP BY  co.ClaimOnLineCode,co.ClaimOnLineId

   ) colPA
    ON colPA.ClaimOnLineCode = chPA.ClaimOnLineCode 
   LEFT JOIN (
    SELECT 
     ClaimOnLineId
     ,SUM(npld.Amount) NPLAmount
    FROM ClaimOnlineV2.dbo.NPLHeader nplh
     INNER JOIN ClaimOnlineV2.dbo.NPLDetail npld
      ON nplh.NPLHeaderId = npld.NPLHeaderId
    WHERE nplh.IsActive = 1
     AND npld.IsActive = 1
    GROUP BY ClaimOnLineId
   )nplds
    ON nplds.ClaimOnLineId = colPA.ClaimOnLineId

  WHERE chgPA.InsuranceCompany_id <> @InsuranceCompanyId
 
 END

-- Claim Misc
ELSE IF @ProductGroupId > 3

 BEGIN

  INSERT INTO #Tmplst(
   ClaimHeaderGroupCode
   ,TransferAmount
   ,Amount
   ,NPLAmount
   ,ClaimCode
   ,WarningMessage
  )
  SELECT 
    cm.ClaimHeaderGroupCode    ClaimHeaderGroupCode
    ,cph.PayAmount      TransferAmount
    ,ISNULL(cm.PayAmount, 0)   Amount
    ,ISNULL(colnlp.NPLAmount, 0)  NPLAmount 
    ,NULL        ClaimCode
    ,(
     ISNULL(
      CASE 
       WHEN ISNULL(cm.PayAmount, 0) = 0 
        THEN @ClaimHeaderGroupAmountWarning + ' , ' 
       ELSE ''
      END, NULL
     )
     +
     ISNULL(
      CASE 
       WHEN ISNULL(cph.PayAmount, 0) <> (ISNULL(cm.PayAmount, 0) + ISNULL(colnlp.NPLAmount, 0))
        THEN CONCAT(@AmountWarning, ' , ')
       ELSE ''
      END, NULL
     )
     +
     ISNULL(
      CASE 
       WHEN NULLIF(cm.PolicyNo ,'')  IS NULL
        THEN CONCAT(@PolicyWarning, ' , ')
       ELSE ''
      END, NULL
     )
     +
     ISNULL(
      CASE 
       WHEN (cph.ClaimMiscId IS NULL OR phxcmp.PaymentStatusId IS NOT NULL)
        THEN CONCAT(@ClaimHeaderPaymentWarning, ' , ')
       ELSE ''
      END, NULL
     ) 
     +
     ISNULL(
      CASE 
       WHEN cls.ClaimOnLineStatusId = 4
        THEN CONCAT(@ClaimOnlineStatusWarning, ' , ')
       ELSE ''
      END, NULL
     )
     ) AS WarningMessage  
     --,cph.*
  FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
   INNER JOIN #Tmp t
    ON cm.ClaimHeaderGroupCode = t.Element
   LEFT JOIN (
    -- NPL
    SELECT 
     nplh.ClaimOnLineId
     ,SUM(npld.Amount) NPLAmount
    FROM ClaimOnlineV2.dbo.NPLHeader nplh
     LEFT JOIN ClaimOnlineV2.dbo.NPLDetail npld
      ON nplh.NPLHeaderId = npld.NPLHeaderId
    WHERE nplh.IsActive = 1
     AND npld.IsActive = 1
    GROUP BY nplh.ClaimOnLineId
   )colnlp
    ON colnlp.ClaimOnLineId = cm.ClaimOnLineId 
   INNER JOIN 
   (
    -- โอนเงิน
    SELECT 
     pv.ClaimMiscId
     ,(ISNULL(pv.[2],0) + ISNULL(pv.[3],0) - ISNULL(pv.[4],0)) PayAmount
    FROM
    (
     SELECT 
      ph.ClaimMiscId  ClaimMiscId 
      ,ph.SumAmount  PayAmount
      ,ph.PaymentTypeId
     FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] ph
     WHERE ph.IsActive = 1
      AND ph.PaymentTypeId IN (2,3,4)
     GROUP BY ph.ClaimMiscId 
      ,ph.PaymentTypeId
      ,ph.SumAmount
    )m 
    PIVOT(
     SUM(m.PayAmount) FOR m.PaymentTypeId IN([2],[3],[4])
    )pv
   )
   cph
    ON cm.ClaimMiscId = cph.ClaimMiscId
   LEFT JOIN (
    -- ตรวจสอบสถานะการโอนเงิน
    SELECT 
     cl.ClaimOnLineStatusId
     ,cl.ClaimOnLineId
    FROM [ClaimOnlineV2].[dbo].ClaimOnline cl
    WHERE cl.IsActive = 1
   )cls
    ON cm.ClaimOnLineId = cls.ClaimOnLineId
   LEFT JOIN (
    SELECT 
     cmp.PaymentStatusId
     ,ph.ClaimMiscId
    FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] ph
     LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cmp
      ON ph.ClaimMiscPaymentHeaderId = cmp.ClaimMiscPaymentHeaderId
    WHERE ph.IsActive = 1
     AND cmp.IsActive = 1
     AND cmp.PaymentStatusId NOT IN (4,5)
   )phxcmp
    ON cm.ClaimMiscId = phxcmp.ClaimMiscId
  WHERE cm.IsActive = 1
    
  END


-- set result
SELECT  
  tmp.ClaimHeaderGroupCode           ClaimHeaderGroupCode 
 ,tmp.Amount               Amount
 ,tmp.NPLAmount              NPLAmount
 ,tmp.TransferAmount             TransferAmount
 ,CASE 
    WHEN doc.DocumentIndexData IS NOT NULL THEN IIF(tmp.WarningMessage IS NULL OR tmp.WarningMessage = '', 1, 0)
    ELSE 0 
    END IsValid
 ,CASE 
    WHEN doc.DocumentIndexData IS NOT NULL THEN tmp.WarningMessage
    ELSE 'ไม่มีเอกสาร' 
    END IsValid
FROM #Tmplst tmp
    LEFT JOIN ISC_SmileDoc.dbo.ClaimDocument doc 
	    ON doc.DocumentIndexData = tmp.ClaimCode COLLATE DATABASE_DEFAULT
 
GROUP BY  tmp.ClaimHeaderGroupCode 
   ,tmp.Amount    
   ,tmp.NPLAmount
   ,tmp.TransferAmount  
   ,tmp.WarningMessage 
   ,doc.DocumentIndexData
   

IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst; 
IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;