path = "app/main.py"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()
target_line = 1105
old = lines[target_line]
print(f"BEFORE: {old.rstrip()}")
new = old.replace(
    '"/api/v1/chart/", "/api/v1/trades/", "/api/v1/market/", "/api/v1/trades/"',
    '"/api/v1/chart/", "/api/v1/trades/", "/api/v1/market/"'
)
if new == old:
    print("ERROR: Pattern not matched. Actual line:")
    print(repr(old))
else:
    lines[target_line] = new
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    print(f"AFTER:  {new.rstrip()}")
    print("SUCCESS")
