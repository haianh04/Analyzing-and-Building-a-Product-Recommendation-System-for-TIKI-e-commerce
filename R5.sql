USE master;
GO

-- Login Admin
CREATE LOGIN Admin_Login
WITH PASSWORD = 'Admin@123',
     CHECK_POLICY = OFF,
     CHECK_EXPIRATION = OFF,
     DEFAULT_DATABASE = DATA_For_ML;
GO

-- Login DE
CREATE LOGIN DE_Login
WITH PASSWORD = 'DE@123',
     CHECK_POLICY = OFF,
     CHECK_EXPIRATION = OFF,
     DEFAULT_DATABASE = DATA_For_ML;
GO

-- Login DA
CREATE LOGIN DA_Login
WITH PASSWORD = 'DA@123',
     CHECK_POLICY = OFF,
     CHECK_EXPIRATION = OFF,
     DEFAULT_DATABASE = DATA_For_ML;
GO
------------
USE DATA_For_ML;
GO

-- Tạo user cho từng login trong cơ sở dữ liệu DATA
CREATE USER Admin_User FOR LOGIN Admin_Login;
GO

CREATE USER DE_User FOR LOGIN DE_Login;
GO

CREATE USER DA_User FOR LOGIN DA_Login;
GO

-- Tạo role Admin và cấp quyền toàn bộ cơ sở dữ liệu cho role này
CREATE ROLE Admin;
GO
GRANT CONTROL ON DATABASE::DATA_For_ML TO Admin;
GO

-- Tạo role DE 
CREATE ROLE DE;
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON DATABASE::DATA_For_ML TO DE; -- Cấp quyền thêm, sửa, xóa, truy vấn dữ liệu 
GRANT EXECUTE ON SCHEMA::dbo TO DE; -- Cấp quyền thực thi các thủ tục và hàm 
GRANT CREATE PROCEDURE TO DE; -- Cấp quyền tạo mới thủ tục 
GRANT CREATE FUNCTION TO DE; -- Cấp quyền tạo mới hàm
GRANT ALTER ON SCHEMA::dbo TO DE; -- Cấp quyền cho phép sửa các thủ tục và hàm 
GRANT CONTROL ON SCHEMA::dbo TO DE; -- Cấp quyền cho phép xóa các thủ tục và hàm 
GO

-- Tạo role DA và cấp quyền truy vấn dữ liệu
CREATE ROLE DA;
GO
GRANT SELECT ON DATABASE::DATA_For_ML TO DA;
GO

-- Thêm các user vào role
ALTER ROLE Admin ADD MEMBER Admin_User;
GO

ALTER ROLE DE ADD MEMBER DE_User;
GO

ALTER ROLE DA ADD MEMBER DA_User;
GO