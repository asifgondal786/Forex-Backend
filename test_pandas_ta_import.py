import sys
try:
    import pandas_ta as ta
    print("pandas_ta imported, version:", getattr(ta, '__version__', 'unknown'))
except Exception as e:
    print("Import failed:", e)
    sys.exit(1)
