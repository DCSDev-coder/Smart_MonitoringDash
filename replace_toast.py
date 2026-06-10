import os
import re

toast_import = "import '../../shared/utils/app_toast.dart';\n"
toast_import_alt = "import '../../../shared/utils/app_toast.dart';\n"
toast_import_main = "import 'shared/utils/app_toast.dart';\n"

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Regex to find ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)))
    # We will try to find patterns like:
    # ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('msg')));
    # ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('msg')));
    # ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ...));
    
    # Actually, let's just do a simpler string replacement for common patterns.
    # Because regexing dart code is fragile.
    pass

# We will just write a simpler AST-like regex.
import sys

def replace_snackbars(root_dir):
    pattern = re.compile(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^)]*\)\s*\);', re.DOTALL)
    
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith('.dart'):
                filepath = os.path.join(dirpath, filename)
                with open(filepath, 'r') as f:
                    content = f.read()
                
                if 'ScaffoldMessenger.of(context).showSnackBar' in content:
                    # check if we need to add import
                    if 'shared/utils/app_toast.dart' not in content:
                        # find relative path to lib/shared/utils/app_toast.dart
                        rel_path = os.path.relpath(os.path.join(root_dir, 'shared/utils/app_toast.dart'), dirpath)
                        import_str = f"import '{rel_path}';\n"
                        # insert after last import
                        lines = content.split('\n')
                        last_import = 0
                        for i, line in enumerate(lines):
                            if line.startswith('import '):
                                last_import = i
                        lines.insert(last_import + 1, import_str.strip())
                        content = '\n'.join(lines)
                    
                    def replacer(match):
                        text_content = match.group(1).strip()
                        # try to guess if it's error or success based on text or color
                        full_match = match.group(0)
                        if 'backgroundColor: AppTheme.statusError' in full_match or 'backgroundColor: Colors.red' in full_match or 'failed' in text_content.lower() or 'error' in text_content.lower() or 'must' in text_content.lower() or 'required' in text_content.lower() or 'denied' in text_content.lower():
                            return f"AppToast.showError(context, {text_content});"
                        elif 'backgroundColor: AppTheme.accentGreen' in full_match or 'success' in text_content.lower() or 'copied' in text_content.lower():
                            return f"AppToast.showSuccess(context, {text_content});"
                        else:
                            return f"AppToast.show(context, {text_content});"
                    
                    new_content = pattern.sub(replacer, content)
                    
                    # Also handle SnackBar without const
                    # ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('...'), backgroundColor: ...));
                    
                    if new_content != content:
                        with open(filepath, 'w') as f:
                            f.write(new_content)
                        print(f"Updated {filepath}")

replace_snackbars('lib')
