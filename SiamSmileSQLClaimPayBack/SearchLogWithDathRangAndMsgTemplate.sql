USE ClaimPayBack ;
GO;

DECLARE @DateFrom DATE = '2025-09-01';
DECLARE @DateTo DATE = '2025-09-03';
DECLARE @StartDateFrom DATETIME2 = @DateFrom;
DECLARE @EndDateTo DATETIME2	= DATEADD(DAY, 1, @DateTo);

SELECT TOP(100000)
	l.Id
	,l.Level
	,l.Message
	,l.MessageTemplate 
	,l.Exception
	,FORMAT(l.TimeStamp, 'dd MM yyyy HH:mm') TimeStamp
FROM EventLogging.SmileSClaimPayBackLogs l
WHERE l.TimeStamp >= @StartDateFrom
AND l.TimeStamp < @EndDateTo
AND l.Message LIKE '%BUAO-888-68070002-0%'

--AND l.Id >= 2388080
--AND l.Id < 2388120


ORDER BY l.TimeStamp 
ASC

