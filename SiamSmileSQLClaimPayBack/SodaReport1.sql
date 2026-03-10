--รบกวนพี่เข้มดึงรายงานระบบ เคลม Payback prod (พี่โซดาขอมาครับ)
--เงื่อนไข
--1.บ.ส. ที่มีการตั้งเบิกแล้ว 
--2.บ.ส. ที่มีกรุ๊ป CPBT แล้ว
--3.ที่มีการตั้งเบิก ตั้งแต่วันที่ 01/01/2026 - ปัจจุบัน
--4.เฉพาะเคลมออนไลน์

--ข้อมูลที่ต้องการ
--1.เลขที่เคลม
--2.เลขที่ บ.ส.
--3.เลขที่กรุ๊ป CPBG
--4.เลขที่กรุ๊ป CPBT
--5.ยอด บ.ส.
--6.วันที่ส่งการเงิน / วันที่ส่งตั้งเบิก
--7.วันที่โอนเงิน/บันทึกโอนเงิน (ถ้ามี)

USE [ClaimPayBack]
GO

SELECT 
	cpbxc.ClaimCode					เลขที่เคลม
	,cpbd.ClaimGroupCode			[เลขที่ บ.ส.]
	,cpb.ClaimPayBackCode			[เลขที่กรุ๊ป CPBG]
	,cpt.ClaimPayBackTransferCode	[เลขที่กรุ๊ป CPBT]
	,cpbd.Amount					[ยอด บ.ส.]
	,cpbd. CreatedDate				[วันที่ส่งการเงิน / วันที่ส่งตั้งเบิก]
	,cpt.TransferDate				[วันที่โอนเงิน/บันทึกโอนเงิน]
FROM dbo.ClaimPayBackDetail cpbd
INNER JOIN dbo.ClaimPayBack cpb
	ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
INNER JOIN dbo.ClaimPayBackTransfer cpt
	ON cpt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
LEFT JOIN dbo.ClaimPayBackXClaim cpbxc
	ON cpbxc.ClaimPayBackDetailId = cpbd.ClaimPayBackDetailId
WHERE cpbd.IsActive = 1
AND cpb.IsActive = 1
AND cpt.IsActive = 1
AND cpb.ClaimGroupTypeId = 2
AND cpb.CreatedDate > '2026-01-01'
ORDER BY cpb.ClaimPayBackCode