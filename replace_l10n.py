import os
import re
import codecs

files = [
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\events\view\events_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\events\view\event_detail_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\home\view\home_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\live_matches\view\live_matches_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\matches\view\matches_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\match_details\view\match_details_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\players\view\player_profile_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\points_table\view\points_table_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\search\view\search_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\spectator\match_detail\view\spectator_match_detail_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\teams\view\team_profile_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\tournaments\view\tournaments_screen.dart",
    r"C:\Users\hp\Documents\GitHub\SportyApp\lib\ui\tournaments\view\tournament_detail_screen.dart"
]

app_localizations_path = r"C:\Users\hp\Documents\GitHub\SportyApp\lib\core\localization\app_localizations.dart"

def to_snake_case(s):
    # Remove emojis and special characters except space
    s = re.sub(r'[^\w\s]', '', s)
    s = s.strip().lower()
    s = re.sub(r'\s+', '_', s)
    # Avoid empty
    if not s:
        return None
    return s[:30] if len(s) > 30 else s

# Existing keys parsing
existing_keys = set()
with codecs.open(app_localizations_path, 'r', 'utf-8') as f:
    loc_content = f.read()

# Naive parse of existing keys
for m in re.finditer(r"'([^']+)'\s*:", loc_content):
    existing_keys.add(m.group(1))

new_keys = {}

# Process each file
for file_path in files:
    if not os.path.exists(file_path):
        print(f"Not found: {file_path}")
        continue
    
    with codecs.open(file_path, 'r', 'utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Simple regex to find Text('something') or Text("something")
    texts = re.findall(r"Text\(\s*'([^'\$]+)'", content)
    texts += re.findall(r'Text\(\s*"([^"\$]+)"', content)
    
    # Filter
    texts = [t for t in texts if t.strip() and t != 'CRIXORA' and not t.isdigit()]
    
    if not texts:
        continue

    # Add import if not present
    if "import 'package:sportyapp/core/localization/app_localizations.dart';" not in content:
        import_idx = content.rfind("import ")
        if import_idx != -1:
            end_of_line = content.find("\n", import_idx)
            content = content[:end_of_line+1] + "import 'package:sportyapp/core/localization/app_localizations.dart';\n" + content[end_of_line+1:]

    # Inject final l10n = AppLocalizations.of(context); in build methods
    # We will do a basic string replace for standard build method signatures
    build_patterns = [
        "Widget build(BuildContext context, WidgetRef ref) {",
        "Widget build(BuildContext context) {"
    ]
    
    for bp in build_patterns:
        l10n_str = "final l10n = AppLocalizations.of(context);"
        if bp in content and l10n_str not in content:
            content = content.replace(bp, bp + "\n    " + l10n_str)
            
    # Replace strings and remove const
    for t in set(texts):
        key = to_snake_case(t)
        if not key: continue
        
        # Avoid duplicate keys if text is different
        original_key = key
        counter = 1
        while key in existing_keys and (key in new_keys and new_keys[key] != t):
            key = f"{original_key}_{counter}"
            counter += 1
            
        new_keys[key] = t
        existing_keys.add(key)
        
        # Remove const from parents (very rudimentary approach: just remove all `const Text` -> `Text`)
        # Better: remove `const` from line or just remove `const` before `Text('t')`
        # and replace `Text('t')` with `Text(l10n.translate('key'))`
        content = content.replace(f"const Text('{t}'", f"Text(l10n.translate('{key}')")
        content = content.replace(f'const Text("{t}"', f"Text(l10n.translate('{key}')")
        content = content.replace(f"Text('{t}'", f"Text(l10n.translate('{key}')")
        content = content.replace(f'Text("{t}"', f"Text(l10n.translate('{key}')")
        
        # Global search and replace of `const` that might break it. Let's do a regex to remove const from preceding widgets if they contain l10n
        # It's safer to just let the user fix const errors, but we can do a quick replace
        # e.g. const EmptyState(...) -> EmptyState(...)
        content = re.sub(r'const\s+([A-Z]\w*\([^)]*l10n\.translate)', r'\1', content, flags=re.DOTALL)
        # Or just remove const from lines containing l10n
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if 'l10n.translate' in line and 'const ' in line:
                lines[i] = line.replace('const ', '')
        content = '\n'.join(lines)
        
    with codecs.open(file_path, 'w', 'utf-8') as f:
        f.write(content)
        print(f"Updated {file_path}")

# Update app_localizations.dart
if new_keys:
    with codecs.open(app_localizations_path, 'r', 'utf-8') as f:
        loc = f.read()
    
    en_entries = []
    ur_entries = []
    for k, v in new_keys.items():
        if v not in loc:
            en_entries.append(f"      '{k}': '{v}',")
            ur_entries.append(f"      '{k}': '{v}',") # using english for urdu as placeholder for now, user can update later or we can try to guess
            
    if en_entries:
        # insert before the end of 'en' map
        en_idx = loc.find("    },\n    'ur': {")
        if en_idx != -1:
            loc = loc[:en_idx] + "\n" + "\n".join(en_entries) + "\n" + loc[en_idx:]
            
        ur_idx = loc.rfind("    },\n  };")
        if ur_idx != -1:
            loc = loc[:ur_idx] + "\n" + "\n".join(ur_entries) + "\n" + loc[ur_idx:]
            
        with codecs.open(app_localizations_path, 'w', 'utf-8') as f:
            f.write(loc)
        print(f"Updated app_localizations.dart with {len(en_entries)} keys")
