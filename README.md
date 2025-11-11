# 🧾 SiamSmileSQLClaimPayBack

ฐานข้อมูลหลักของระบบ **Claim PayBack** ภายใต้โครงการ **SmilesInsurance**

---

## 📅 เวอร์ชันอัปเดตล่าสุด
**วันที่:** 2025-10-14  
**สถานะ:** ✅ ใช้งานใน Production แล้ว

---

## 📂 รายการ Stored Procedures ที่อัปเดต

# 🔍 SiamSmileSQLClaimPayBack – Change Log (UAT_V1.3.1 → master)

| No | File / Stored Procedure | Action | Description / Change Detail | Commit Date | Commit SHA |
|----|--------------------------|---------|------------------------------|--------------|-------------|
| 1 | usp_BillingClaimMiscExport_Select.sql | 🆕 Add | เพิ่ม SP สำหรับ Export Billing Claimmisc ใช้ดึงข้อมูลเคลมเบ็ดเตล็ด | 2025-10-30 | 01a171c |
| 2 | usp_BillingPAExportDetail_Select.sql | ✏️ Fix | แก้ไขฟิลด์ Remark ให้ใช้ `ch.AccidentDetail` และระบุคอลัมน์แทน `v.*` | 2025-10-30 | 9956cc9 |
| 3 | usp_BillingRequest_Insert_V3.sql | ✏️ Fix | เพิ่มเงื่อนไข ClaimMisc (`WHEN f.ClaimHeaderGroupTypeId = 6`) | 2025-10-30 | 0f79afd |
| 4 | usp_BillingRequest_Sub01_Insert_V2.sql | ✏️ Fix | รองรับ ClaimMisc, เพิ่ม test DECLARE block, ปรับ filter ClaimTypeCode, เพิ่ม ClaimGroupTypeId = 6 | 2025-10-30 | 9ec0fdd |
| 5 | usp_ClaimHeaderGroupDetail_SelectV4.sql | ⚙️ Update | เปลี่ยน join product group → DataCenterV1.Product.ProductGroup, กรอง IsActive, map ClaimMiscNo | 2025-10-30 | cc444ff |
| 6 | usp_ClaimHeaderGroupImport_Insert.sql | 🆕 Add | เพิ่ม SP สำหรับ Import ข้อมูล ClaimHeaderGroup (สร้างใหม่) | 2025-10-30 | 4c83aae |
| 7 | usp_ClaimHeaderGroupImport_Select.sql | ✏️ Fix | เพิ่ม UNION ALL ดึงข้อมูล ClaimMisc, join Branch เพื่อแปลง branch code | 2025-10-30 | 955a0d7 |
| 8 | usp_ClaimPayBackDetail_InsertV4.sql | ⚙️ Update | เปลี่ยน join product group, ลบ join payment เดิม, ใช้ ClaimMiscNo, ปรับ Begin Tran ใหม่ | 2025-11-07 | 8864fe5 |
| 9 | usp_ClaimPayBackDetail_InsertV4_Backup_20251106.sql | 🆕 Add | เพิ่มไฟล์แบ็กอัป SP ตัวเต็ม (วันที่ 2025-11-06) | 2025-11-07 | 8800754 |
| 10 | usp_ClaimPayBackReportNonClaimCompensate_Select.sql | ✏️ Fix | เพิ่มส่วน UNION ClaimMisc สำหรับรายงานที่ไม่มี ClaimCompensate | 2025-11-06 | b9c1e0e |
| 11 | usp_ClaimPayBackTransferNonClaimCompensateReport_Select.sql | ⚙️ Refactor | เปลี่ยนโครงสร้าง temp table #TmpPersonUser, เพิ่มดัชนี, join ตารางจริงแทนวิว, union ClaimMisc | 2025-10-29 | bea4b87 |
| 12 | usp_TmpClaimHeaderGroupImport_Validate_V2.sql | ⚙️ Update | เพิ่ม support ClaimMisc, mapping ClaimGroupType=6, join DocumentList, ปรับ ValidateResult | 2025-11-11 | 072f127 |
| 13 | usp_BillingClaimMiscExport_Select_Test.sql | 🧪 Add | สคริปต์ทดสอบ Billing Claimmisc export พร้อมค่า param ตัวอย่าง | 2025-10-30 | fb6afa5 |
| 14 | SearchSP.sql | ✏️ Fix | เปลี่ยนคำค้นจาก ClaimMiscCode → ClaimMiscNo | 2025-11-07 | 8800754 |
| 15 | SiamSmileSQLClaimPayBack.ssmssqlproj | ⚙️ Update | เพิ่มการอ้างอิงไฟล์ใหม่ (Import/Backup SP) และ connection ใหม่ | 2025-10-30 | 4c83aae |
| 16 | README.md | 📝 Update | ปรับสารบัญ, เพิ่มรายการ SP ที่อัปเดตและวันที่ | 2025-11-10 | 9a8df45 |
                                                                                                                            |
