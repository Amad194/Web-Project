from flask import Flask, jsonify, request
from flask_mysqldb import MySQL

app = Flask(__name__)

# MySQL Configuration
app.config['MYSQL_HOST'] = 'mydb.cxph3yvsgltz.us-east-1.rds.amazonaws.com'
app.config['MYSQL_USER'] = 'admin'
app.config['MYSQL_PASSWORD'] = 'admin123'
app.config['MYSQL_DB'] = 'mydb'

mysql = MySQL(app)

# Create visitors table if not exists
cur = mysql.connection.cursor()
cur.execute('''
    CREATE TABLE IF NOT EXISTS visitors (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
''')
cur.close()

@app.route('/visitors', methods=['POST'])
def add_visitor():
    if request.method == 'POST':
        name = request.json.get('name', '')
        if not name:
            return jsonify({'error': 'Name is required'}), 400
        
        cur = mysql.connection.cursor()
        cur.execute('INSERT INTO visitors (name) VALUES (%s)', (name,))
        mysql.connection.commit()
        cur.close()

        return jsonify({'message': 'Visitor added successfully'}), 201

@app.route('/visitors', methods=['GET'])
def get_visitors():
    cur = mysql.connection.cursor()
    cur.execute('SELECT id, name, visit_time FROM visitors ORDER BY visit_time DESC')
    visitors = cur.fetchall()
    cur.close()

    visitors_list = [{'id': visitor[0], 'name': visitor[1], 'visit_time': visitor[2]} for visitor in visitors]
    return jsonify({'visitors': visitors_list}), 200

if __name__ == '__main__':
    app.run(debug=True)
