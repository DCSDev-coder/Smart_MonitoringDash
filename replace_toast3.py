import re

def update_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Generic replaces
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Username is required.')),\n      );", "AppToast.showError(context, 'Username is required.');")
    
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(content: Text(msg), backgroundColor: AppTheme.statusError),\n    );", "AppToast.showError(context, msg);")
    
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text(msg), backgroundColor: AppTheme.statusError),\n      );", "AppToast.showError(context, msg);")

    # Add missing import
    if 'AppToast' in content and 'app_toast.dart' not in content:
        lines = content.split('\n')
        idx = 0
        for i, l in enumerate(lines):
            if l.startswith('import '):
                idx = i
        import_str = "import '../../shared/utils/app_toast.dart';"
        lines.insert(idx + 1, import_str)
        content = '\n'.join(lines)
    
    with open(path, 'w') as f:
        f.write(content)

update_file('lib/features/admin/add_user_screen.dart')

def update_auth(path):
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Please fill all fields')),\n      );", "AppToast.showError(context, 'Please fill all fields');")
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text('Login failed: $e'),\n          backgroundColor: AppTheme.statusError,\n        ),\n      );", "AppToast.showError(context, 'Login failed: $e');")
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text(msg),\n          backgroundColor: AppTheme.statusError,\n        ),\n      );", "AppToast.showError(context, msg);")
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Session restored successfully'),\n          backgroundColor: AppTheme.accentGreen,\n        ),\n      );", "AppToast.showSuccess(context, 'Session restored successfully');")
    
    if 'AppToast' in content and 'app_toast.dart' not in content:
        lines = content.split('\n')
        idx = 0
        for i, l in enumerate(lines):
            if l.startswith('import '):
                idx = i
        import_str = "import '../../shared/utils/app_toast.dart';"
        lines.insert(idx + 1, import_str)
        content = '\n'.join(lines)
    
    with open(path, 'w') as f:
        f.write(content)
        
update_auth('lib/features/auth/auth_screen.dart')

print("Updated add_user and auth screens")
