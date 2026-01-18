import mariadb
from slpp import slpp as lua
import os

# === CONFIGURATION ===
LUA_PATH = r"C:\Program Files (x86)\World of Warcraft\_classic_era_\WTF\Account\138524079#1\SavedVariables\CatgirlTracker.lua"
DB_CONFIG = {
    "host": "10.13.12.2",
    "port": 3306,
    "user": "shiva",
    "password": "miebei6aev8lieD4coh3sh",
    "database": "catgirlsyncdb"
}

# === PARSE LUA WITH SLPP ===
def extract_lua_tables(filepath):
    with open(filepath, encoding="utf-8") as f:
        lua_code = f.read()

    tables = {}
    for block in ["CatgirlGuildDB", "CatgirlZoneDB", "CatgirlPetDB", "CatgirlEmoteDB", "CatgirlBehaviorDB"]:
        if block + " = {" in lua_code:
            start = lua_code.find(block + " = ")
            brace = start + lua_code[start:].find("{")
            depth = 1
            end = brace + 1
            while depth > 0 and end < len(lua_code):
                if lua_code[end] == "{":
                    depth += 1
                elif lua_code[end] == "}":
                    depth -= 1
                end += 1
            try:
                lua_table = lua_code[start + len(block + " = "):end]
                tables[block] = lua.decode(lua_table)
            except Exception as e:
                print(f"⚠️ Failed to decode {block}:", e)
    return tables

# === DB FUNCTIONS ===

def get_connection():
    return mariadb.connect(**DB_CONFIG)

def create_table_if_not_exists(cursor, kitten, log_type, log_entries):
    table_name = f"{log_type}_{kitten}".lower()
    cursor.execute(f"CREATE TABLE IF NOT EXISTS `{table_name}` (id INT PRIMARY KEY AUTO_INCREMENT)")

    cursor.execute(f"SHOW COLUMNS FROM `{table_name}`")
    existing_cols = {row[0] for row in cursor.fetchall()}

    all_keys = set()
    for entry in log_entries:
        if isinstance(entry, dict):
            all_keys.update(entry.keys())

    for key in all_keys:
        if key not in existing_cols:
            sample_value = next((e[key] for e in log_entries if isinstance(e, dict) and key in e), "")
            col_type = "BIGINT" if isinstance(sample_value, int) else "TEXT"
            try:
                cursor.execute(f"ALTER TABLE `{table_name}` ADD COLUMN `{key}` {col_type}")
                print(f"🛠️ Added column `{key}` to `{table_name}`.")
            except mariadb.ProgrammingError as e:
                print(f"⚠️ Could not add column `{key}`: {e}")

def entry_exists(cursor, kitten, log_type, entry):
    table = f"{log_type}_{kitten}".lower()

    if log_type == "ZoneLog":
        if not all(k in entry for k in ("timestamp", "zone", "instanceType")):
            return False
        query = f"""SELECT COUNT(*) FROM `{table}`
                    WHERE timestamp = ? AND zone = ? AND instanceType = ?"""
        params = (entry["timestamp"], entry["zone"], entry["instanceType"])

    elif log_type == "PetLog":
        if "timestamp" not in entry or "event" not in entry:
            return False
        query = f"""SELECT COUNT(*) FROM `{table}`
                    WHERE timestamp = ? AND event = ?"""
        params = (entry["timestamp"], entry["event"])

    elif "unixtime" in entry:
        query = f"""SELECT COUNT(*) FROM `{table}` WHERE unixtime = ?"""
        params = (entry["unixtime"],)

    else:
        return False

    cursor.execute(query, params)
    return cursor.fetchone()[0] > 0

def insert_entry(cursor, kitten, log_type, entry):
    table = f"{log_type}_{kitten}".lower()
    keys = list(entry.keys())
    values = [entry[k] for k in keys]
    placeholders = ", ".join(["?"] * len(values))
    cursor.execute(f"INSERT INTO `{table}` ({', '.join(keys)}) VALUES ({placeholders})", values)

# === MAIN SYNC ===

def sync_all():
    data = extract_lua_tables(LUA_PATH)
    if not data:
        print("No valid data found.")
        return

    conn = get_connection()
    cur = conn.cursor()

    log_types = {
        "CatgirlGuildDB": "GuildLog",
        "CatgirlZoneDB": "ZoneLog",
        "CatgirlPetDB": "PetLog",
        "CatgirlEmoteDB": "EmoteLog",
        "CatgirlBehaviorDB": "BehaviorLog"
    }

    for db_key, log_key in log_types.items():
        db = data.get(db_key, {})
        logs = db.get(log_key, {})

        for kitten, entries in logs.items():
            if not isinstance(entries, list) or not entries:
                continue

            create_table_if_not_exists(cur, kitten, log_key, entries)

            for entry in entries:
                if not isinstance(entry, dict):
                    continue
                if not entry_exists(cur, kitten, log_key, entry):
                    insert_entry(cur, kitten, log_key, entry)

    conn.commit()
    cur.close()
    conn.close()
    print("✅ Sync complete.")

# === ENTRY POINT ===
if __name__ == "__main__":
    sync_all()
