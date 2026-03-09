import re, os
base = r'lib/screens/parent'
files = ['parent_dashboard','parent_profile','parent_tracking','parent_schedule',
         'parent_notifications','parent_fees','parent_layout','help_support_screen',
         'language_screen','change_password_screen','emergency_contacts_screen',
         'trip_history_screen','rate_app_screen','subscription_screen']
for f in files:
    path = os.path.join(base, f+'.dart')
    c = open(path, encoding='utf-8').read()
    matches = sorted(set(re.findall(r"'([A-Z][a-zA-Z &\-!?,./0-9']{3,})'", c)))
    if matches:
        print(f'=== {f} ===')
        for m in matches:
            print(f'  {m}')
