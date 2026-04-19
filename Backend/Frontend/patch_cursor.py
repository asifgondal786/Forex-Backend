path = r"D:\Tajir\Frontend\lib\config\theme.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old = "    return ButtonStyle(\n      padding:"
new = "    return ButtonStyle(\n      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),\n      padding:"

if old in content:
    content = content.replace(old, new, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Done - mouseCursor added to glassElevatedButtonStyle")
else:
    print("ERROR: pattern not found - check indentation")
