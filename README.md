# 🧾 SiamSmileSQLClaimPayBack

ฐานข้อมูลหลักของระบบ **Claim PayBack** ภายใต้โครงการ **SmilesInsurance**

---

## 📅 เวอร์ชันอัปเดตล่าสุด
**วันที่:** 2025-10-14  
**สถานะ:** ✅ ใช้งานใน Production แล้ว

---

## 📂 รายการ Stored Procedures ที่อัปเดต

### 🗓️ 2025-10-09 — Import SP (Batch 1)
| ชื่อ Stored Procedure | รายละเอียด |
|------------------------|-------------|
| `usp_ClaimPayBackDetail_InsertV4` | เพิ่มขั้นตอนการ Insert รายละเอียด Claim PayBack |
| `usp_ClaimHeaderGroupDetail_SelectV4` | ปรับโครงสร้างการดึงข้อมูล Header Group ให้รองรับ Version 4 |

---

### 🗓️ 2025-10-14 — Import SP (Batch 2)
| ชื่อ Stored Procedure | รายละเอียดการเปลี่ยนแปลง |
|------------------------|------------------------------|
| `usp_ClaimPayBackByTransfer_Select` | เพิ่มฟังก์ชันสำหรับดึงข้อมูล PayBack ที่จ่ายโดยการโอน |
| `usp_ClaimPayBackTransfer_Select` | 🔧 **แก้ไข:** เพิ่มเงื่อนไข `AND t.ClaimGroupTypeId IN (4,7)` เพื่อกรองข้อมูลเฉพาะกลุ่มที่เกี่ยวข้อง |
| `usp_ClaimPayBackTransferNonClaimCompensateReport_Select` | 🔧 **แก้ไข:** เพิ่ม **UNION ClaimMisc** เพื่อรวมข้อมูลจากตาราง Claim Miscellaneous |

---

## 📘 หมายเหตุ
- ทุก Stored Procedure ผ่านการทดสอบในสภาพแวดล้อม UAT แล้ว  
- การปรับปรุงโค้ดทั้งหมดใช้โครงสร้าง schema `claim.*` และ `misc.*`  
- แนะนำให้สำรองฐานข้อมูลก่อน deploy ทุกครั้ง

---

## 🧑‍💻 ผู้ดูแล
**ทีม:** SmilesInsurance Claim System  
**ผู้รับผิดชอบ:** Solomon Hunter  
**อีเมล:** dev@smilessystem.co.th  
**อัปเดตล่าสุด:** 2025-10-14 09:00 (GMT+7)
