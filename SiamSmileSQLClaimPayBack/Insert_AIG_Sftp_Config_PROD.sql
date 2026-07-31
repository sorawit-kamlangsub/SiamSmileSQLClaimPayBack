INSERT INTO [dbo].[SFTPConfig] 
(
[SFTPConfigId]
, [PathIN]
, [PathOUT]
, [PathBackUp]
, [InsuranceCompanyCode]
, [IsActive]
, [Host]
, [Port]
, [Username]
, [Password]
, [MailTo]
, [MailCc]
, [DocumentExpiry]
) 
VALUES (
13
, '/Home/aigthssb03/Claim/IN'
, '/Home/aigthssb03/Claim/Out'
, 'D:/DocumentFiles/Claim/ClaimPayBack/AIG'
, '100000000042'
, '1'
, N'167.230.146.38'
, N'9022'
, N'AIGTHSSB04'
, N'c6~UTydH_6GG4?o?7Cs}9nV^'
, 'jirayu.s@siamsmile.co.th,sorawit.kam@gmail.com'
, 'jirayu.s@siamsmile.co.th,sorawit.kam@gmail.com'
, 45
);
