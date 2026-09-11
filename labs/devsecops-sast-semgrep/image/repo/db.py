"""
Camada de acesso a dados — contém SQL Injection intencional pro lab.
"""
import sqlite3


def get_connection():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES ('alice'), ('bob')")
    return conn


def find_user_by_name(name):
    conn = get_connection()
    # VULNERÁVEL: o valor do usuário é interpolado direto na query via
    # f-string. Um valor tipo "' OR '1'='1" muda a lógica da query.
    query = f"SELECT * FROM users WHERE name = '{name}'"
    cursor = conn.execute(query)
    return cursor.fetchall()
