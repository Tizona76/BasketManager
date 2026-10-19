"""Synthetic Godot 4.5.1 tests. Copies code to a private temporary project.
Never starts production autoloads, contacts a backend or reads personal saves.
"""
from pathlib import Path
import subprocess,shutil,re
r=Path(__file__).resolve().parents[4]
import tempfile,os
t=Path(tempfile.mkdtemp(prefix='bc-steam-purchase-tests-',dir='/private/tmp'));os.chmod(t,0o700)
p=t/'project';p.mkdir()
(p/'scripts').mkdir(exist_ok=True);(p/'tests/steam_wallet').mkdir(parents=True,exist_ok=True)
for n in ('PlayerLife','ProfileManager','LeagueData','StadiumData','LocalIO','SteamWallet','SteamPurchases'):
 src=r/'client/godot/scripts'/(n+'.gd')
 shutil.copy2(src,p/'scripts'/src.name)
for src in (r/'client/godot/tests/steam_wallet').glob('*.gd'):shutil.copy2(src,p/'tests/steam_wallet'/src.name)

(p/'scripts/PlayerLife_baseline.gd').write_bytes(subprocess.check_output(['git','show','ac1862d:client/godot/scripts/PlayerLife.gd'],cwd=r))
menu=(r/'client/godot/scenes/menu.gd').read_text();symbols=('SeasonState','Session','ProfileManager','AudioManager','I18nSvc','SaveSingleton','MobilePinchZoom')
(p/'menu_under_test.gd').write_text(menu.replace('extends Control','extends Control\n'+'\n'.join('var '+n+': Variant' for n in symbols),1))
shop=(r/'client/godot/scripts/ShopTokens.gd').read_text()
import json
(p/'scripts/ShopTokens_original.gd').write_text(subprocess.check_output(['git','show','ac1862d:client/godot/scripts/ShopTokens.gd'],cwd=r).decode())
(p/'scripts/ShopTokens_updated.gd').write_text(shop)
(p/'shop_under_test.gd').write_text(shop.replace('extends Control','extends Control\n'+'\n'.join('var '+n+': Variant' for n in symbols),1))
(p/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Steam Synthetic Only"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
version=subprocess.check_output(['/Applications/Godot.app/Contents/MacOS/Godot','--version'],text=True)
assert version.startswith('4.5.1.')
total=0
import sys
names=sys.argv[1:] or ['test_steam_purchase','test_steam_wallet','test_steam_persistence','test_steam_cloud','test_steam_cloud_menu']
for n in names:
 cmd=['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(p),'--script','res://tests/steam_wallet/'+n+'.gd','--log-file',str(t/(n+'.engine.log')),'--','--fixture-root='+str(t/(n+'_fixtures')),'--baseline-playerlife='+str(p/'scripts/PlayerLife_baseline.gd')]
 out=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60);(t/(n+'.log')).write_text(out.stdout)
 print(out.stdout[-5500:]);counts=re.findall(r'RESULT (\d+) PASS / (\d+) FAIL',out.stdout)
 if out.returncode or len(counts)!=1 or int(counts[0][1]) or 'SCRIPT ERROR' in out.stdout:sys.exit(1)
 total+=int(counts[0][0])
print('TOTAL',total,'PASS / 0 FAIL; diagnostics:',t)
