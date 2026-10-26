import sys, glob, re
root = sys.argv[1]
mf = f'{root}/android/app/src/main/AndroidManifest.xml'
s = open(mf).read()
perms = ''.join(f'<uses-permission android:name="android.permission.{p}"/>' for p in
  ['WAKE_LOCK','FOREGROUND_SERVICE','FOREGROUND_SERVICE_MEDIA_PLAYBACK','READ_MEDIA_AUDIO','POST_NOTIFICATIONS']) + \
  '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>'
s = s.replace('<application', perms + '<application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Cadence"', s, count=1)
svc = ('<service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true">'
  '<intent-filter><action android:name="android.media.browse.MediaBrowserService"/></intent-filter></service>'
  '<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">'
  '<intent-filter><action android:name="android.intent.action.MEDIA_BUTTON"/></intent-filter></receiver>')
assert '</application>' in s
s = s.replace('</application>', svc + '</application>', 1)
open(mf, 'w').write(s)
ks = glob.glob(f'{root}/android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
assert ks, 'MainActivity.kt not found'
for k in ks:
    open(k, 'w').write('package com.tanimsarker.cadence\n\nimport com.ryanheise.audioservice.AudioServiceActivity\n\nclass MainActivity : AudioServiceActivity()\n')
pl = f'{root}/ios/Runner/Info.plist'
p = open(pl).read()
add = ('<key>UIBackgroundModes</key><array><string>audio</string></array>'
  '<key>UIFileSharingEnabled</key><true/><key>LSSupportsOpeningDocumentsInPlace</key><true/>')
i = p.rfind('</dict>')
p = p[:i] + add + p[i:]
p = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*', r'\1Cadence', p)
open(pl, 'w').write(p)
print('native config patched')
