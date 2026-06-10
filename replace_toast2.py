import re

def update_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # We will just do textual replacements
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Please enter both username and password.')),\n      );", "AppToast.showError(context, 'Please enter both username and password.');")
    
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Password created successfully. You can now log in.'),\n          backgroundColor: AppTheme.accentGreen,\n        ),\n      );", "AppToast.showSuccess(context, 'Password created successfully. You can now log in.');")
    
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text(msg), backgroundColor: AppTheme.statusError),\n      );", "AppToast.showError(context, msg);")

    # For reset password dialog
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Please fill all password fields.')),\n      );", "AppToast.showError(context, 'Please fill all password fields.');")
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('New password must be at least 8 characters.')),\n      );", "AppToast.showError(context, 'New password must be at least 8 characters.');")
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('New password and confirmation do not match.')),\n      );", "AppToast.showError(context, 'New password and confirmation do not match.');")
    content = content.replace("ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Password reset failed. Check your current password and try again.'),\n          backgroundColor: AppTheme.statusError,\n        ),\n      );", "AppToast.showError(context, 'Password reset failed. Check your current password and try again.');")

    # inject import if missing
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
    print("Updated", path)

update_file('lib/features/auth/setup_user_screen.dart')
update_file('lib/shared/widgets/reset_password_dialog.dart')

