# วิเคราะห์สาเหตุ Error Saving File BQGPA04B6909001

**วันที่วิเคราะห์:** 2026-09-02
**แหล่งข้อมูล:** `Logs\SmileSClaimPayBackLogsPROD20260902.json`

## สรุปสาเหตุ

ไฟล์ `BQGPA04B6909001-20260902.xlsx` ถูก **Lock/เปิดค้างโดย process อื่น** ทำให้ตอนที่ EPPlus (`ExcelPackage.Save()`) พยายามจะ **ลบไฟล์เดิมก่อนเพื่อ overwrite** (`File.InternalDelete`) ไม่สามารถลบได้

```
System.IO.IOException: The process cannot access the file
'D:\DocumentFiles\Claim\ClaimPayBack\TempBilling\BQGPA04B6909001-20260902.xlsx'
because it is being used by another process.
```

จุดที่เกิด Error (จาก stack trace):

```
at OfficeOpenXml.ExcelPackage.Save()
at ClaimPayBackController.<ExportExcelClaimPayBackBillingRequestGroupChub>d__82.MoveNext()
   ClaimPayBackController.cs:line 4032
```

> หมายเหตุ: โค้ดต้นทาง `ClaimPayBackController.cs` ไม่ได้อยู่ใน repo นี้ (repo เป็น SQL Server project) จึงอ้างอิงได้จาก stack trace ที่ชี้ไปที่เครื่อง build เท่านั้น

## หลักฐานจาก Log

พบ Error ซ้ำกัน **อย่างน้อย 13 รอบ** ในไฟล์ log เดียวกัน (ตั้งแต่เวลาประมาณ 10:36 จนถึง 10:54 น.):

1. ทุกครั้งจะเห็นคู่เหตุการณ์:
   - `Start ExportExcelClaimPayBackBillingRequestGroupChub [billingRequestGroupId = 21256, billingRequestGroupCode = "BQGPA04B6909001", actionId = 1]`
   - ผ่านไป ~5 วินาที → `Error saving file ... BQGPA04B6909001-20260902.xlsx`
2. ไฟล์เดียวกันนี้ถูกอ้างอิงโดยขั้นตอนอื่นด้วย:
   - `Start UploadFilesToSFTPChub [excelName = "BQGPA04B6909001-20260902.xlsx" ...]` (log line 5170, 6952)
   - มี Error เพิ่มเติมในการ Upload ไฟล์ PDF รายการ (log line 6313-6318)
3. พบ Error รูปแบบเดียวกันนี้กับไฟล์อื่น เช่น `BQGPA04H6909001-20260902.xlsx` (log line 5224-5228) ซึ่งยืนยันว่าเป็นปัญหา **เชิงระบบ (shared temp folder + ชื่อไฟล์ deterministic)** ไม่ใช่เฉพาะไฟล์เดียว

## ลักษณะของปัญหา

- ชื่อไฟล์เป็น **deterministic / ตายตัว**: `{billingRequestGroupCode}-{yyyyMMdd}.xlsx`
- ทุก Export ใช้โฟลเดอร์ `TempBilling` ร่วมกัน
- EPPlus เมื่อ `Save()` ไปยังไฟล์ที่มีอยู่แล้ว จะ **ลบไฟล์เดิมก่อน** แล้วจึงเขียนใหม่
- ถ้าไฟล์นั้นถูกเปิด/ถือไว้อีกที (เช่นโดย request อื่น, โปรแกรมเปิดดู, หรือ antivirus) → การลบจะล้มเหลว → Error ตามที่เห็น
- การเกิดซ้ำๆ ในหลายช่วงเวลา บ่งชี้ว่าเป็น **การเรียก Export พร้อมกัน/ซ้ำกันหลายครั้ง** ที่เขียนไฟล์ชื่อเดียวกันในโฟลเดอร์เดียวกัน

## สาเหตุที่เป็นไปได้ (เรียงตามน้ำหนัก)

1. **การเรียก Export พร้อมกัน/ซ้ำกัน (Race Condition)** — Export ถูก trigger หลายครั้ง (user หรือ background job) โดยทุก request เขียนไฟล์ชื่อเดียวกัน → request ที่มาทีหลังชนกับไฟล์ที่ยังเปิดค้างจาก request แรก
2. **ไฟล์ถูกเปิดค้างไว้ใน Excel / File Preview** ของผู้ใช้บนเครื่อง Server หรือ network share
3. **Antivirus / Windows Defender** กำลังสแกนไฟล์ `.xlsx` ที่เพิ่งถูกเขียน และ lock ไฟล์ไว้ชั่วครู่
4. **`UploadFilesToSFTPChub`** เปิดอ่านไฟล์ xlsx เดิมค้างไว้ชั่วขณะ ส่งผลให้ Export รอบถัดไป overwrite ไม่ได้

## แนวทางแก้ไข (แนะนำ)

- **ใช้ชื่อไฟล์ชั่วคราวแบบไม่ชนกัน** เช่น `{code}-{yyyyMMdd}-{guid}.xlsx` แล้วค่อย `File.Move`/rename เป็นชื่อจริง เพื่อหลีกเลี่ยงการชนกันของไฟล์
- **เพิ่ม Retry** รอบ `Save()` ประมาณ 2-3 ครั้ง (หน่วงสั้นๆ) เพื่อผ่านสถานะ lock ชั่วครู่ของ antivirus
- **Dispose `ExcelPackage` ให้จบใน `using` ทันที** หลัง `Save()` และตรวจสอบว่า SFTP upload ไม่ถือ `FileStream` ของไฟล์ xlsx ค้างไว้
- เปิดไฟล์ด้วย **`FileShare.ReadWrite`** ในส่วนที่ต้องอ่านไฟล์ร่วมกัน เพื่อไม่ให้ block การ overwrite
- หากสาเหตุมาจาก user เปิดไฟล์ค้างไว้จริง ควรเขียนไปยังโฟลเดอร์ per-request แทนการใช้โฟลเดอร์ `TempBilling` ร่วมกัน

## ไฟล์ข้อมูลอ้างอิง

- `Logs\SmileSClaimPayBackLogsPROD20260902.json`
