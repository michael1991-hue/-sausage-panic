"""Select the newest installed stable Xcode with the required upload SDK."""
import pathlib, plistlib, subprocess
candidates=[]
for app in pathlib.Path('/Applications').glob('Xcode*.app'):
    if 'beta' in app.name.lower():
        continue
    with (app/'Contents/Info.plist').open('rb') as f:
        info=plistlib.load(f)
    version=tuple(int(v) for v in info['CFBundleShortVersionString'].split('.'))
    if version[0] >= 26:
        candidates.append((version,str(app/'Contents/Developer')))
if not candidates:
    raise SystemExit('Xcode 26 or newer is required. Select a GitHub runner image with the current iOS SDK.')
subprocess.run(['sudo','xcode-select','--switch',max(candidates)[1]],check=True)
subprocess.run(['xcodebuild','-version'],check=True)
