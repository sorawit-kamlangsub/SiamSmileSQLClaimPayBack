USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroup_Insert]    Script Date: 25/5/2569 16:39:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroup_Insert]    Script Date: 10/25/2023 9:30:52 AM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:  Sahatsawat golffy 06958
-- Create date: 20230908
-- Update date: 2026-05-25 Sorawit.k เพิ่มการเช็คเคลมเบ็ดเตล็ด(โรงพยาบาล) 
-- Description: For Group ClaimHospital and ClaimCompensate
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackSubGroup_Insert]
-- Add the parameters for the stored procedure here
 @ClaimPayBackTransferId  INT
 ,@CreatedByUserId   INT
AS
BEGIN
 -- SET NOCOUNT ON added to prevent extra result sets from
 -- interfering with SELECT statements.
 SET NOCOUNT ON;

 -- For Test
 --DECLARE @ClaimPayBackTransferId INT = 389
 --DECLARE @CreatedByUserId INT = 4957

 -- Add the parameters for the stored procedure here
 DECLARE @IsResult   BIT    = 1;
 DECLARE @Result    VARCHAR(100) = '';
 DECLARE @Msg    NVARCHAR(500) = '';

 DECLARE @CreatedDate    DATETIME2 = GETDATE();
 DECLARE @ClaimPayBackSubGroupCount INT = 0;
 DECLARE @ClaimGroupTypeId   INT;

 -- Validate
 SELECT @ClaimPayBackSubGroupCount = COUNT(ClaimPayBackSubGroupId) 
 FROM dbo.ClaimPayBackSubGroup
 WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId

 IF @ClaimPayBackSubGroupCount > 0
  BEGIN
      SET @IsResult = 0;
   SET @Msg = N'ถูก Generate Group แล้ว';
  END

 SELECT @ClaimGroupTypeId = ClaimGroupTypeId 
 FROM dbo.ClaimPayBack 
 WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId

 IF @ClaimGroupTypeId NOT IN (4,8)
 BEGIN
  SET @IsResult = 0;
  SET @Msg = N'ต้องเป็นเคลมโรงพยาบาลเท่านั้น';
 END

 IF (@IsResult = 1)
  BEGIN

   SELECT cd.ClaimPayBackDetailId
     , cd.ItemCount
     , cd.Amount
     , cd.HospitalCode
     , h.Detail AS HospitalName
     , cd.CreatedDate
     , c.ClaimPayBackTransferId
     --, cd.ProductGroupId
     --, pdg.ProductGroupDetail AS ProductGroup
     ,h.ContactEmail
   INTO #TmpHeader
   FROM dbo.ClaimPayBackDetail cd
   LEFT JOIN sss.dbo.vw_CompanyGroupHospital h
    ON cd.HospitalCode = h.Code
   INNER JOIN dbo.ClaimPayBack c
    ON cd.ClaimPayBackId = c.ClaimPayBackId
   --LEFT JOIN DataCenterV1.Product.ProductGroup pdg
   -- ON cd.ProductGroupId = pdg.ProductGroup_ID
   WHERE c.ClaimPayBackTransferId = @ClaimPayBackTransferId
    AND cd.IsActive = 1

   SELECT COUNT(ClaimPayBackDetailId)  ItemCount
     , SUM(Amount)     SumAmount 
     , HospitalCode     HospitalCode
     , MAX(HospitalName)    HospitalName
     , ROW_NUMBER() OVER(ORDER BY (HospitalCode) asc ) AS rwId
     , ContactEmail
   INTO #TmpGroup
   FROM #TmpHeader
   GROUP BY HospitalCode, ContactEmail;

   DECLARE @TT          VARCHAR(6) = 'HCG'
      , @Total   INT 
      , @YY          VARCHAR(2)
      , @MM          VARCHAR(2)
      , @RunningFrom INT
      , @RunningTo   INT;

   SELECT @Total = MAX(rwId)
   FROM #TmpGroup;

   EXECUTE dbo.usp_GenerateCode_FromTo @TT -- varchar(6)
             , @Total -- int
             , @YY OUTPUT -- varchar(2)
             , @MM OUTPUT -- varchar(2)
             , @RunningFrom OUTPUT -- int
             , @RunningTo OUTPUT -- int

 
   -- สร้าง ClaimPayBackSubGroup และเก็บ ClaimPayBackSubGroupId ที่สร้างขึ้นใหม่
   DECLARE @GeneratedIds TABLE (ClaimPayBackSubGroupId INT, HospitalCode VARCHAR(20))

   --SELECT * FROM #TmpHeader
   --SELECT * FROM #TmpGroup

   -----------------------------------
   BEGIN TRY
    BEGIN TRANSACTION
 

    INSERT INTO dbo.ClaimPayBackSubGroup
    (
     ClaimPayBackSubGroupCode
     , Amount
     , ItemCount
     , HospitalCode
     , HospitalName
     , ClaimPayBackTransferId
     , IsActive
     , CreatedDate
     , CreatedByUserId
     , UpdatedDate
     , UpdatedByUserId
     , ContactEmail
    )
    OUTPUT INSERTED.ClaimPayBackSubGroupId, INSERTED.HospitalCode INTO @GeneratedIds (ClaimPayBackSubGroupId, HospitalCode)
    SELECT CONCAT(@TT,@YY,@MM ,FORMAT(@RunningFrom + rwId - 1,'000000')) 
     , SumAmount
     , ItemCount
     , HospitalCode
     , HospitalName
     , @ClaimPayBackTransferId
     , 1
     , @CreatedDate
     , @CreatedByUserId
     , @CreatedDate
     , @CreatedByUserId
     , ContactEmail
    FROM #TmpGroup

    -- อัปเดต ClaimPayBackDetail ด้วย ClaimPayBackSubGroupId
    UPDATE CPBD
    SET CPBD.ClaimPayBackSubGroupId = GID.ClaimPayBackSubGroupId
     , CPBD.UpdatedDate = @CreatedDate
     , CPBD.UpdatedByUserId = @CreatedByUserId
    FROM dbo.ClaimPayBackDetail CPBD
    INNER JOIN #TmpHeader TH 
     ON CPBD.ClaimPayBackDetailId = TH.ClaimPayBackDetailId
    INNER JOIN @GeneratedIds GID 
     ON TH.HospitalCode = GID.HospitalCode;
 
    SET @IsResult   = 1;
    SET @Msg        = 'บันทึก สำเร็จ';
 
    COMMIT TRANSACTION
   END TRY
   BEGIN CATCH
 
    SET @IsResult   = 0;
    SET @Msg        = 'บันทึก ไม่สำเร็จ';
 
    IF (@@Trancount > 0) ROLLBACK;
   END CATCH
   -----------------------------------

  IF OBJECT_ID('tempdb..#TmpHeader') IS NOT NULL  DROP TABLE #TmpHeader;
  IF OBJECT_ID('tempdb..#TmpGroup') IS NOT NULL  DROP TABLE #TmpGroup;
 
 END;
 
 IF (@IsResult = 1) 
  BEGIN
   SET @Result = 'Success';
  END
 ELSE
  BEGIN
   SET @Result = 'Failure';
  END; 
 
 SELECT @IsResult AS IsResult
   ,@Result AS Result
   ,@Msg  AS Msg;
 
END;