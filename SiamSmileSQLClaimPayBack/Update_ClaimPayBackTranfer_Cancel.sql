USE [ClaimPayBack]
GO

DECLARE @UpdatedByUserId INT = 1
DECLARE @ClaimPayBackTransferId INT
DECLARE @i INT = 1
DECLARE @max INT

DECLARE @List TABLE (
    RowNum INT IDENTITY(1,1),
    Id INT
)

INSERT INTO @List (Id)
VALUES 
(4148)
,(4149)
,(4151)
,(4153)
,(4154)
,(4155)
,(4257)
,(4263)

SELECT @max = COUNT(*) FROM @List

WHILE @i <= @max
BEGIN
    SELECT @ClaimPayBackTransferId = Id 
    FROM @List 
    WHERE RowNum = @i

    DECLARE @return_value INT

    EXEC @return_value = [dbo].[usp_ClaimPayBackTranfer_Cancel]
        @ClaimPayBackTransferId = @ClaimPayBackTransferId,
        @UpdatedByUserId = @UpdatedByUserId

    PRINT 'ID: ' + CAST(@ClaimPayBackTransferId AS VARCHAR) 
        + ' Return: ' + CAST(@return_value AS VARCHAR)

    SET @i = @i + 1
END