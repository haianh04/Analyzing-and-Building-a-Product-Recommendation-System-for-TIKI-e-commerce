import requests
import time
import random

###
sql_insert_product = '''
    USE DATA1
    INSERT INTO Tiki_Product
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
'''

sql_insert_customer = '''
    USE DATA1
    INSERT INTO Tiki_Customer
    VALUES (?, ?)
'''

sql_insert_comment = '''
    USE DATA1
    INSERT INTO Tiki_Comment
    VALUES (?,?,?,?,?)
'''
###
import pypyodbc as odbc
DRIVER = 'SQL Server'
SERVER_NAME = 'DESKTOP-FR4PQFU\SQL'
DATABASE_NAME = 'DATA1'
USER_NAME = 'sa'
PASSWORD = 'Dhl@2001'
def connection_string(driver, server_name, database_name, username, password):
    conn_string = f"""
        DRIVER={{{driver}}};
        SERVER={server_name};
        DATABASE={database_name};
        username={username};
        password={password};
        Trust_Connection=yes;
    """
    return conn_string

try:
    conn = odbc.connect(connection_string(DRIVER, SERVER_NAME, DATABASE_NAME, USER_NAME, PASSWORD))
except odbc.DatabaseError as e:
    print('Database Error:')
    print(str(e.value[1]))
except odbc.Error as e:
    print('Connection Error:')
    print(str(e.value[1]))

###
def insert_data(data, sql_insert_query, cursor):
    try:
        cursor.execute(sql_insert_query, data)
    except Exception as e:
        print(f"Lỗi insert dữ liệu: {e}")

def insert_data_customer(customer_data, insert_query, cursor):
    cursor.execute("SELECT * FROM Tiki_Customer WHERE Customer_id = %s" %(customer_data[0],))
    existing_customer = cursor.fetchone()
    if existing_customer:
        pass
    else:
        cursor.execute(insert_query, customer_data)

# Định nghĩa header chung
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'vi,en;q=0.9,en-GB;q=0.8,en-US;q=0.7',
    'x-guest-token': '8w2SAbPrsE7CvdHx56jTZ0UDBYi3mhQF',
    'Connection': 'keep-alive',
    'TE': 'Trailers',
}
###
def parser_product(json):
    d = dict()
    d['product_id'] = json.get('id')
    d['product_name'] = json.get('name')
    d['price'] = json.get('price')
    d['original_price'] = json.get('original_price')
    d['discount'] = json.get('discount')
    d['discount_rate'] = json.get('discount_rate')    
    try:
        d['review_count'] = json.get('review_count')
    except AttributeError:
        d['review_count'] = 0        
    try:   
        d['rating_avg'] = json.get('rating_average')
    except AttributeError:
        d['rating_avg'] = 0
    try:
        d['order_count'] = json.get('quantity_sold').get('value')
    except AttributeError:
        d['order_count'] = 0
    d['inventory_status'] = json.get('inventory_status')
    try:
        d['brand_id'] = json.get('brand').get('id')
    except AttributeError:    
        d['brand_id'] = None
    try:
        d['brand_name'] = json.get('brand').get('name')
    except AttributeError:
        d['brand_name'] = None
    d['category'] = json['breadcrumbs'][0]['name']
    d['sub_category'] = json['breadcrumbs'][1]['name']
    return d

def customer_parser(json):
    d = dict()
    d['customer_id']  = json.get('customer_id')
    try:
        d['customer_name'] = json.get('created_by').get('name')
    except AttributeError:
        d['customer_name'] = None
    return d

def comment_parser(json):
    d = dict()
    d['customer_id']  = json.get('customer_id')
    d['product_id'] = json.get('product_id')
    d['title'] = json.get('title')
    d['rating'] = json.get('rating')   
    try:
        d['purchased_at'] = json.get('created_by').get('purchased_at') 
    except AttributeError:
        d['purchased_at'] = None
    return d

cursor = conn.cursor()

list_category_id_1 = {1883, 1789, 2549, 1815, 1882, 1520} 
list_category_id_2 = {8594, 931, 4384, 1975, 915, 1846 ,1686} 
list_category_id_3 = {4221, 1703, 1801, 27498, 8371, 6000, 15078}

for c_id in list_category_id_1:
    for i in range(1, 41):
        params = {'limit': '40', 'page': str(i), 'category': str(c_id)}
        print('page',[i],'category',[c_id])
        response = requests.get('https://tiki.vn/api/personalish/v1/blocks/listings', headers=headers, params=params)
        if response.status_code == 200:
            for record in response.json().get('data'):
                pid = record.get('id')
                response1 = requests.get(f'https://tiki.vn/api/v2/products/{pid}', headers=headers, timeout=10)
                if response1.status_code == 200:
                    product_data = parser_product(response1.json())
                    product_data = list(product_data.values())
                    insert_data(product_data, sql_insert_product, cursor)   
                    
                print('Crawl comment for product {}'.format(pid))
                for j in range(1,11):
                    params2 = {'limit': '5', 'page': str(j), 'spid': pid, 'product_id': pid}
                    response = requests.get('https://tiki.vn/api/v2/reviews', headers=headers, params=params2, timeout=10)
                    if response.status_code == 200:
                            for comment in response.json().get('data'):
                                customer_data = customer_parser(comment)
                                customer_data = list(customer_data.values())
                            
                                comment_data = comment_parser(comment)
                                comment_data = list(comment_data.values())
                            
                                insert_data_customer(customer_data,sql_insert_customer, cursor)
                                insert_data(comment_data, sql_insert_comment, cursor)
                time.sleep(random.randrange(0, 2))
                cursor.commit()
cursor.commit()
            
            

