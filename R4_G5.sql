--1. 
CREATE PROCEDURE  DeleteRowsWithNull
AS
BEGIN
    DELETE FROM Tiki_Comment
    WHERE Title IS NULL
       OR Rating IS NULL
       OR Purchased_at IS NULL;
END;
--2.
CREATE FUNCTION CheckForNullValues() 
RETURNS BIT
AS
BEGIN
    DECLARE @has_null BIT;

    SELECT 
        @has_null = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM 
        Tiki_Comment
    WHERE 
        Title IS NULL 
        OR Rating IS NULL 
        OR Purchased_at IS NULL;

    RETURN @has_null;
END;
SELECT dbo.CheckForNullValues() AS NullRecordCount;
--3.
CREATE TRIGGER trg_UpdateRatingOnComment
ON Tiki_Comment
AFTER INSERT
AS
BEGIN
    -- Cập nhật Rating_avg cho Tiki_Product sau khi thêm bình luận mới vào Tiki_Comment
    UPDATE Tiki_Product
    SET Rating_avg = (
        SELECT AVG(CAST(c.Rating AS FLOAT))  -- Tính trung bình các rating
        FROM Tiki_Comment c
        WHERE c.Product_id = i.Product_id
    ),
    Review_count = (
        SELECT COUNT(*)
        FROM Tiki_Comment c
        WHERE c.Product_id = i.Product_id
    )
    FROM inserted i
    WHERE Tiki_Product.Product_id = i.Product_id;
END;
BACKUP DATABASE [DATA_For_ML] 
TO DISK = 'D:\DATA_Backup\Full_Backup.bak' 
WITH FORMAT, INIT, NAME = 'Full Backup of DATA_For_ML';
BACKUP DATABASE [DATA_For_ML] 
TO DISK = 'D:\DATA_Backup\Differential_Backup.bak' 
WITH DIFFERENTIAL, INIT;
BACKUP LOG [DATA_For_ML] 
TO DISK = 'D:\DATA_Backup\Log_Backup.trn' 
WITH INIT;

-- Lịch chạy Full Backup: Mỗi tuần một lần (chủ nhật 12 giờ sáng)
EXEC sp_add_jobschedule  
   @job_name = N'Auto_Backup_DATA_For_ML',  
   @name = N'Weekly Full Backup',  
   @freq_type = 8,  -- Chạy hàng tuần
   @freq_interval = 1,  -- Chủ nhật
   @active_start_time = 000000; -- 12:00 tối
GO

-- Lịch chạy Differential Backup: Mỗi ngày vào 12 giờ tối
EXEC sp_add_jobschedule  
   @job_name = N'Auto_Backup_DATA_For_ML',  
   @name = N'Daily Differential Backup',  
   @freq_type = 4,  -- Chạy hàng ngày
   @freq_interval = 1,  
   @active_start_time = 000000; -- 12:00 tối
GO

-- Lịch chạy Log Backup: Mỗi 15 phút
EXEC sp_add_jobschedule  
   @job_name = N'Auto_Backup_DATA_For_ML',  
   @name = N'15-Minute Log Backup',  
   @freq_type = 4,  -- Lặp lại hàng ngày
   @freq_interval = 1,  -- Chạy mỗi ngày
   @freq_subday_type = 4,  -- Lặp lại theo phút
   @freq_subday_interval = 15,  -- Mỗi 15 phút
   @active_start_time = 000000, -- Bắt đầu từ 12:00 sáng
   @active_end_time = 235959; -- Kết thúc lúc 11:59 tối
GO

--Kiểm tra tính toàn vẹn của backup
RESTORE VERIFYONLY
FROM DISK = 'C:\DATA_Backup\Full_Backup.bak';

--Giám sát sao lưu qua Mail
DECLARE @message NVARCHAR(MAX);
SET @message = '';

SELECT @message += 'Database: ' + name + CHAR(10) +
                   'Last Full Backup: ' + ISNULL(CONVERT(VARCHAR, MAX(backup_finish_date)), 'No Backup') + CHAR(10) + CHAR(10)
FROM msdb.dbo.backupset
WHERE type = 'D'
GROUP BY name;

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'BackupAlerts',
    @recipients = 'phanxuanhaianh@gmail.com',
    @subject = 'Weekly Backup Report',
    @body = @message;

--Kiểm tra lịch sử sao lưu
SELECT
    database_name,
    backup_start_date,
    backup_finish_date,
    CASE
        WHEN type = 'D' THEN 'Full Backup'
        WHEN type = 'I' THEN 'Differential Backup'
        WHEN type = 'L' THEN 'Transaction Log Backup'
    END AS BackupType,
    physical_device_name
FROM msdb.dbo.backupset
INNER JOIN msdb.dbo.backupmediafamily
ON backupset.media_set_id = backupmediafamily.media_set_id
ORDER BY backup_finish_date DESC;

-- phục hồi dữ liệu
CREATE DATABASE ppp
DROP TABLE [dbo].[Tiki_Brand], [dbo].[Tiki_Comment], [dbo].[Tiki_Customer], [dbo].[Tiki_Product]
RESTORE DATABASE [DATA_For_ML]
FROM DISK = 'C:\DATA_Backup\FullBackup.bak'
WITH REPLACE, RECOVERY;

