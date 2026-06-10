import os
import re

def get_bracket_content(s, start_idx):
    """Extracts content between matched brackets starting at start_idx."""
    count = 0
    in_str = False
    str_char = None
    
    for i in range(start_idx, len(s)):
        c = s[i]
        
        # handle strings so we don't count brackets inside them
        if c in ("'", '"'):
            if not in_str:
                in_str = True
                str_char = c
            elif str_char == c:
                # check if escaped
                if s[i-1] != '\\':
                    in_str = False
        
        if not in_str:
            if c == '(':
                count += 1
            elif c == ')':
                count -= 1
                if count == 0:
                    return s[start_idx:i+1], i
    return None, -1

def convert_snackbar_to_apptoast(snack_str):
    # snack_str looks like: (SnackBar(content: Text('Invalid credentials'), backgroundColor: Colors.red))
    # or (const SnackBar(content: Text('Hello')))
    content_match = re.search(r"content:\s*(Text\((.*?)\)|const Text\((.*?)\))", snack_str, re.DOTALL)
    if not content_match:
        # fallback
        return None
    
    text_val = content_match.group(2) if content_match.group(2) else content_match.group(3)
    text_val = text_val.strip()
    
    # check if error or success
    lower_snack = snack_str.lower()
    if 'statuserror' in lower_snack or 'colors.red' in lower_snack or 'failed' in lower_snack or 'invalid' in lower_snack or 'incorrect' in lower_snack or 'error' in lower_snack or 'must' in lower_snack:
        return f"AppToast.showError(context, {text_val});"
    elif 'accentgreen' in lower_snack or 'success' in lower_snack or 'unlocked' in lower_snack or 'copied' in lower_snack:
        return f"AppToast.showSuccess(context, {text_val});"
    else:
        return f"AppToast.show(context, {text_val});"

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content
    
    # We look for "ScaffoldMessenger.of(context).showSnackBar"
    # Actually, let's look for ".showSnackBar" and trace backwards
    
    offset = 0
    while True:
        idx = content.find("showSnackBar", offset)
        if idx == -1:
            break
            
        # check where the parentheses start
        paren_idx = content.find("(", idx)
        if paren_idx != -1:
            snack_str, end_idx = get_bracket_content(content, paren_idx)
            if snack_str:
                # find start of ScaffoldMessenger
                start_idx = content.rfind("ScaffoldMessenger", 0, idx)
                if start_idx != -1 and idx - start_idx < 100:
                    # we have the full chunk: content[start_idx:end_idx+1]
                    # Also there's typically a semicolon after.
                    semicolon_idx = content.find(";", end_idx)
                    full_end = semicolon_idx + 1 if semicolon_idx != -1 and semicolon_idx - end_idx < 5 else end_idx + 1
                    
                    full_chunk = content[start_idx:full_end]
                    new_chunk = convert_snackbar_to_apptoast(snack_str)
                    
                    if new_chunk:
                        content = content[:start_idx] + new_chunk + content[full_end:]
                        # offset needs adjustment
                        offset = start_idx + len(new_chunk)
                        continue
        offset = idx + 12

    if content != original:
        # inject import
        if 'AppToast' in content and 'app_toast.dart' not in content:
            # find root lib dir
            parts = filepath.split('/')
            try:
                lib_idx = parts.index('lib')
                rel_parts = ['..'] * (len(parts) - lib_idx - 2)
                if len(rel_parts) == 0:
                    import_path = "shared/utils/app_toast.dart"
                else:
                    import_path = '/'.join(rel_parts) + "/shared/utils/app_toast.dart"
                
                import_str = f"import '{import_path}';"
                
                lines = content.split('\n')
                last_import = 0
                for i, l in enumerate(lines):
                    if l.startswith('import '):
                        last_import = i
                lines.insert(last_import + 1, import_str)
                content = '\n'.join(lines)
            except ValueError:
                pass
            
        with open(filepath, 'w') as f:
            f.write(content)
        print("Updated", filepath)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

