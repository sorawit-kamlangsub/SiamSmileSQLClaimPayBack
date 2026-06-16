/* ======================================================================
   Parameters — เปลี่ยนค่า 2 ตัวนี้เพื่อทดสอบ claim group / บริษัทประกันอื่น
   ====================================================================== */
DECLARE @InsuranceOrgId       VARCHAR(50) = '1120992';
DECLARE @ClaimHeaderGroupCode VARCHAR(50) = 'AGAO-181-69060001-0';

/* ======================================================================
   Step 1: ตรวจสอบเงื่อนไขเดิม (ทำครั้งเดียว) ว่า ClaimHeaderGroup นี้
   ผูกอยู่กับบริษัทประกัน @InsuranceOrgId จริงหรือไม่
   ====================================================================== */

SELECT
      hg.Code AS ClaimHeaderGroupCode
INTO  #ClaimContext
FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
INNER JOIN SSSPA.dbo.DB_ClaimHeader AS h
    ON hg.Code = h.ClaimheaderGroup_id
LEFT JOIN DataCenterV1.Organize.Organize AS ins
    ON hg.InsuranceCompany_id = ins.OrganizeCode
WHERE ins.Organize_ID = @InsuranceOrgId;
-- หมายเหตุ: ส่วน LEFT JOIN ctd/cus/ctp ในซับควรรีเดิมไม่มีผลต่อผลลัพธ์ของ
-- ขั้นตอนนี้ (ใช้แค่กรอง ins.Organize_ID) จึงตัดออกได้โดยไม่กระทบผลลัพธ์

/* ======================================================================
   Step 2: ดึงข้อมูลแต่ละตาราง โดยอ้างอิงเงื่อนไขผ่าน EXISTS กับ #ClaimContext
   (เทียบเท่ากับ INNER JOIN rs เดิม แต่ไม่ต้อง join ซ้ำกับตารางที่ filter
   ด้วย literal อยู่แล้ว)
   ====================================================================== */

-- 1) ClaimHeaderGroup
SELECT hg.*
FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
WHERE hg.Code = @ClaimHeaderGroupCode
  AND EXISTS (SELECT 1 FROM #ClaimContext cc WHERE cc.ClaimHeaderGroupCode = hg.Code);

-- 2) ClaimHeader
SELECT h.*
FROM SSSPA.dbo.DB_ClaimHeader AS h
WHERE h.ClaimheaderGroup_id = @ClaimHeaderGroupCode
  AND EXISTS (SELECT 1 FROM #ClaimContext cc WHERE cc.ClaimHeaderGroupCode = h.ClaimheaderGroup_id);

-- 3) CustomerDetail
SELECT ctd.*
FROM SSSPA.dbo.DB_ClaimHeader AS h
LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
    ON h.CustomerDetail_id = ctd.Code
WHERE h.ClaimheaderGroup_id = @ClaimHeaderGroupCode
  AND EXISTS (SELECT 1 FROM #ClaimContext cc WHERE cc.ClaimHeaderGroupCode = h.ClaimheaderGroup_id);

-- 4) Customer
SELECT cus.*
FROM SSSPA.dbo.DB_ClaimHeader AS h
LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
    ON h.CustomerDetail_id = ctd.Code
LEFT JOIN SSSPA.dbo.DB_Customer AS cus
    ON ctd.Application_id = cus.App_id
   AND cus.Status_id <> '3090'
WHERE h.ClaimheaderGroup_id = @ClaimHeaderGroupCode
  AND EXISTS (SELECT 1 FROM #ClaimContext cc WHERE cc.ClaimHeaderGroupCode = h.ClaimheaderGroup_id);

-- 5) CustomerPolicy (ไม่กรอง PolicyType_id ตามพฤติกรรมเดิมของ query นี้)
SELECT ctp.*
FROM SSSPA.dbo.DB_ClaimHeader AS h
LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
    ON h.CustomerDetail_id = ctd.Code
LEFT JOIN SSSPA.dbo.DB_Customer AS cus
    ON ctd.Application_id = cus.App_id
   AND cus.Status_id <> '3090'
LEFT JOIN SSSPA.dbo.DB_CustomerPolicy AS ctp
    ON cus.App_id = ctp.App_id
WHERE h.ClaimheaderGroup_id = @ClaimHeaderGroupCode
  AND EXISTS (SELECT 1 FROM #ClaimContext cc WHERE cc.ClaimHeaderGroupCode = h.ClaimheaderGroup_id);

IF OBJECT_ID('tempdb..#ClaimContext') IS NOT NULL DROP TABLE #ClaimContext;