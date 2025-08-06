--Tạo CSDL mới
CREATE DATABASE DATA_FOR_ML;
USE DATA_For_ML;

---Tạo các bảng chứa những trường dữ liệu cần thiết từ dữ liệu thu thập được 
CREATE TABLE Tiki_Product (
        Product_id INT PRIMARY KEY,
        Product_name NVARCHAR(300),
        Price MONEY,
        Original_price MONEY,
        Discount MONEY,
        Discount_rate FLOAT,
        Rating_avg FLOAT,
        Inventory_status VARCHAR(20),
        Brand_id VARCHAR(10),
        Brand_name NVARCHAR(100),
        Category NVARCHAR(100),
        Sub_category NVARCHAR(100)
    )   
CREATE TABLE Tiki_Customer (
        Customer_id INT PRIMARY KEY,
        Customer_name NVARCHAR(100)
    )
CREATE TABLE Tiki_Comment (
        Comment_id INT PRIMARY KEY IDENTITY(1,1),
        Customer_id INT,
        Product_id INT,
        Title NVARCHAR(300),
        Rating FLOAT,
        Purchased_at_old INT,
        CONSTRAINT fk_cus_id FOREIGN KEY(Customer_id) REFERENCES Tiki_Customer(Customer_id),
        CONSTRAINT fk_pid FOREIGN KEY(Product_id) REFERENCES Tiki_Product(Product_id)
    )

CREATE TABLE Tiki_Brand (
    Brand_id VARCHAR(10) PRIMARY KEY,
    Brand_name NVARCHAR(100)
	);


-- Chèn dữ liệu vào bảng Brand (nếu có dữ liệu về nhãn hiệu trong bảng cũ)
INSERT INTO Tiki_Brand(Brand_id,Brand_name)
SELECT DISTINCT Brand_id, Brand_name
FROM [DATA].[dbo].[Tiki_Product];

-- Chèn dữ liệu vào bảng Tiki_Customer
INSERT INTO Tiki_Customer (Customer_id, Customer_name)
SELECT Customer_id, Customer_name
FROM [DATA].[dbo].[Tiki_Customer];

-- Chèn dữ liệu vào bảng Tiki_Product
INSERT INTO Tiki_Product (Product_id, Product_name, Price, Original_price, Discount, Discount_rate, Rating_avg, Inventory_status, Brand_id, Category, Sub_category)
SELECT Product_id, Product_name, Price, Original_price, Discount, Discount_rate, Rating_avg, Inventory_status, Brand_id, Category, Sub_category
FROM [DATA].[dbo].[Tiki_Product];

-- Chèn dữ liệu vào bảng Tiki_Comment
SET IDENTITY_INSERT Tiki_Comment ON;
INSERT INTO Tiki_Comment (Comment_id, Customer_id, Product_id, Title, Rating, Purchased_at_old)
SELECT Comment_id, Customer_id, Product_id, Title, Rating, Purchased_at
FROM [DATA].[dbo].[Tiki_Comment];
SET IDENTITY_INSERT Tiki_Comment OFF;

--Bước 2: Thêm khóa ngoại cho Tiki_Product để tham chiếu đến Brand
ALTER TABLE Tiki_Product
ADD CONSTRAINT FK_Tiki_Product_Brand
FOREIGN KEY (Brand_id) REFERENCES Tiki_Brand(Brand_id)

-- Bước 3: Xóa các cột không cần thiết khỏi bảng Tiki_Product
ALTER TABLE Tiki_Product
DROP COLUMN Brand_name;


---Đổi ngày từ UnixTimestamp sang DateTime
ALTER TABLE [DATA_For_ML].[dbo].[Tiki_Comment] 
ADD Purchased_at DATETIME;

UPDATE [DATA_For_ML].[dbo].[Tiki_Comment]
SET Purchased_at = FORMAT(DATEADD(SECOND, CAST(Purchased_at_old AS BIGINT), '1970-01-01'), 'yyyy-MM-dd HH:mm:ss');

ALTER TABLE [DATA_For_ML].[dbo].[Tiki_Comment] 
DROP COLUMN Purchased_at_old;

--Kiểm tra giá trị null
CREATE FUNCTION CheckForNullValue() 
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
---Xóa các giá trị null
CREATE PROCEDURE  DeleteRowsWithNull
AS
BEGIN
    DELETE FROM Tiki_Comment
    WHERE Title IS NULL
       OR Rating IS NULL
       OR Purchased_at IS NULL;
END;

------------- Một số hàm và thủ tục khác 
--Kiểm tra sản phẩm trùng lặp
CREATE TRIGGER CheckUniqueProductName
ON Tiki_Product
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE Product_name = inserted.Product_name
			AND Brand_name = inserted.Brand_name
    )
    BEGIN
        RAISERROR('Error: Product name must be unique within the same brand.', 16, 1)
        ROLLBACK TRANSACTION
    END
END

SELECT
	*
FROM
	Tiki_Product
WHERE Product_id = 8157209
	
insert into Tiki_Product(Product_id,Product_name,Brand_name)
values (81572091, N'Bánh Chocopie h?p 20 cái','Chocopie')

--Xóa bình luận sau khi xóa sản phẩm
CREATE TRIGGER DeleteCommentsAfterProductDelete
ON Tiki_Product
AFTER DELETE
AS
BEGIN
    DELETE FROM Tiki_Comment
    WHERE Product_id IN (SELECT Product_id FROM deleted)
END

---Kiểm tra bình luận hợp lệ
CREATE TRIGGER ValidateCommentData
ON Tiki_Comment
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM inserted 
        WHERE Rating < 1 OR Rating > 5
    )
    BEGIN
        RAISERROR('Error: Rating must be between 1 and 5.', 16, 1)
        ROLLBACK TRANSACTION
    END

    IF EXISTS (
        SELECT 1 
        FROM inserted 
        WHERE NOT EXISTS (
            SELECT 1 
            FROM Tiki_Customer 
            WHERE Customer_id = inserted.Customer_id
        )
    )
    BEGIN
        RAISERROR('Error: Customer does not exist.', 16, 1)
        ROLLBACK TRANSACTION
    END

    IF EXISTS (
        SELECT 1 
        FROM inserted 
        WHERE NOT EXISTS (
            SELECT 1 
            FROM Tiki_Product 
            WHERE Product_id = inserted.Product_id
        )
    )
    BEGIN
        RAISERROR('Error: Product does not exist.', 16, 1)
        ROLLBACK TRANSACTION
    END
END

--Cập nhật rating trung bình 
CREATE TRIGGER trg_UpdateRatingOnComment
ON Tiki_Comment
AFTER INSERT
AS
BEGIN
    UPDATE Tiki_Product
    SET Rating_avg = (
        SELECT AVG(CAST(c.Rating AS FLOAT)) 
        FROM Tiki_Comment c
        WHERE c.Product_id = i.Product_id
    ),
    Review_count = 
       (SELECT COUNT(*)
        FROM Tiki_Comment c
        WHERE c.Product_id = i.Product_id)
    FROM inserted i
    WHERE Tiki_Product.Product_id = i.Product_id;
END;

--Cập nhật lại % giảm giá sau khi đổi giá sản phẩm 
CREATE TRIGGER UpdateDiscountRateOnPriceChange
ON Tiki_Product
AFTER UPDATE
AS
BEGIN
    IF UPDATE (Price) OR UPDATE (Original_price)
    BEGIN
        UPDATE Tiki_Product
        SET         Discount_rate = ROUND(((Original_price - Price) / Original_price) * 100, 0)
        WHERE   Product_id = (SELECT Product_id FROM INSERTED);
    END;
END;


---
