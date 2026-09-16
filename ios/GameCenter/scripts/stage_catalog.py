#!/usr/bin/env python3
"""Create missing Game Center catalog entries; never releases or submits content.

Existing metadata must match the manifest. Use --verify-only for read-only checks.
Authentication is handled entirely by the installed asc CLI/keychain.
"""
import argparse
import hashlib
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / 'catalog.json').read_text())
APP = CATALOG['appId']
LOCALE = CATALOG['locale']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--verify-only', action='store_true')
args = parser.parse_args()

def asc(*parts, allow_missing=False):
    command = ['asc', 'game-center', *map(str,parts), '--output', 'json']
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        if allow_missing and ('not found' in result.stderr.lower() or '404' in result.stderr):
            return {'data': None}
        raise RuntimeError(f"{' '.join(command)}\n{result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else {}

def mutate(*parts):
    if args.verify_only:
        raise RuntimeError(f"Missing catalog resource (verify-only): {' '.join(map(str, parts))}")
    return asc(*parts)

def apple_api(path, method='GET', payload=None):
    # Keep the short-lived bearer token in memory; never print or persist it.
    token_result = subprocess.run(['asc','auth','token','--confirm','--output','text'],capture_output=True,text=True,check=True)
    if method != 'GET' and args.verify_only:
        raise RuntimeError(f'Missing catalog resource (verify-only): {path}')
    headers = {'Authorization':'Bearer '+token_result.stdout.strip()}
    body = None
    if payload is not None:
        headers['Content-Type'] = 'application/json'
        body = json.dumps(payload).encode()
    request = Request('https://api.appstoreconnect.apple.com'+path,method=method,headers=headers,data=body)
    with urlopen(request,timeout=30) as response:
        return json.load(response)

def read_activity_with_relationships(resource_id):
    # asc's activity view omits the API's include option.
    query = urlencode({'include':'achievements,leaderboards','fields[gameCenterActivities]':'referenceName,vendorIdentifier,minimumPlayersCount,maximumPlayersCount,supportsPartyCode,playStyle,achievements,leaderboards'})
    return apple_api(f'/v1/gameCenterActivities/{resource_id}?{query}')['data']

def default_activity_image(version_id, path):
    result = asc('activities','versions','default-image','view','--id',version_id)
    remote = result.get('data') or {}
    image_path = ROOT / path
    if not remote.get('id'):
        payload = {'data':{'type':'gameCenterActivityImages','attributes':{'fileName':image_path.name,'fileSize':image_path.stat().st_size},'relationships':{'version':{'data':{'type':'gameCenterActivityVersions','id':version_id}}}}}
        remote = apple_api('/v1/gameCenterActivityImages','POST',payload)['data']
    state = remote.get('attributes',{}).get('assetDeliveryState',{}).get('state')
    if state == 'AWAITING_UPLOAD':
        if args.verify_only:
            raise RuntimeError(f'Activity default artwork not uploaded: {path}')
        remote = apple_api('/v1/gameCenterActivityImages/'+remote['id'])['data']
        contents = image_path.read_bytes()
        for op in remote['attributes']['uploadOperations']:
            request = Request(op['url'],method=op['method'],data=contents[op['offset']:op['offset']+op['length']],headers={h['name']:h['value'] for h in op['requestHeaders']})
            with urlopen(request,timeout=30) as response:
                response.read()
        payload = {'data':{'type':'gameCenterActivityImages','id':remote['id'],'attributes':{'uploaded':True}}}
        apple_api('/v1/gameCenterActivityImages/'+remote['id'],'PATCH',payload)
    for _ in range(15):
        remote = asc('activities','versions','default-image','view','--id',version_id)['data']
        attrs = remote['attributes']
        if attrs.get('assetDeliveryState',{}).get('state') == 'COMPLETE':
            break
        time.sleep(2)
    attrs = remote['attributes']
    matches(attrs.get('imageAsset',{}),{'width':3840,'height':2160},path+' default image')
    matches(attrs,{'fileName':image_path.name,'fileSize':image_path.stat().st_size},path+' default image')
    matches(attrs['assetDeliveryState'],{'state':'COMPLETE'},path+' default image')
    return {'id':remote['id'],'fileName':image_path.name,'width':3840,'height':2160,'state':'COMPLETE','sha256':hashlib.sha256(image_path.read_bytes()).hexdigest()}

def matches(actual, expected, context):
    for key, value in expected.items():
        if actual.get(key) != value:
            raise RuntimeError(f'{context}: {key}: remote={actual.get(key)!r}, expected={value!r}')

def image_for(group, localization_id, path):
    result = asc(group, 'localizations', 'image', 'view', '--id', localization_id, allow_missing=True)
    if not (result.get('data') or {}).get('id'):
        mutate(group, 'images', 'upload', '--localization-id', localization_id, '--file', ROOT / path)
        result = asc(group, 'localizations', 'image', 'view', '--id', localization_id)
    for _ in range(15):
        attrs = result['data']['attributes']
        if attrs.get('imageAsset') and attrs.get('assetDeliveryState',{}).get('state') == 'COMPLETE':
            break
        if attrs.get('assetDeliveryState',{}).get('state') == 'FAILED':
            raise RuntimeError(f'Asset processing failed: {path}')
        time.sleep(2)
        result = asc(group, 'localizations', 'image', 'view', '--id', localization_id)
    item = result['data']
    attrs = item['attributes']
    expected_size = 3840 if group == 'activities' else 1024
    expected_height = 2160 if group == 'activities' else 1024
    matches(attrs.get('imageAsset',{}), {'width':expected_size,'height':expected_height},path)
    matches(attrs,{'fileName':Path(path).name,'fileSize':(ROOT/path).stat().st_size},path)
    state = attrs['assetDeliveryState']['state']
    if state not in ('COMPLETE','UPLOAD_COMPLETE'):
        raise RuntimeError(f'Asset processing incomplete: {path}: {state}')
    return {'id':item['id'],'fileName':attrs['fileName'],'width':expected_size,'height':expected_height,'state':state,'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest()}

report = {'verifiedAt':datetime.now(timezone.utc).isoformat(),'appId':APP,'locale':LOCALE,'publication':'STAGED_ONLY','achievements':[],'leaderboards':[],'activities':[],'relationshipWrites':[]}
achievement_ids = {}
leaderboard_ids = {}

existing = {r['attributes']['vendorIdentifier']:r for r in asc('achievements','list','--app',APP,'--paginate')['data']}
for item in CATALOG['achievements']:
    remote = existing.get(item['id'])
    if remote is None:
        remote = mutate('achievements','create','--app',APP,'--reference-name',item['name'],'--vendor-id',item['id'],'--points',item['points'])['data']
    resource_id = remote['id']
    matches(remote['attributes'],{'referenceName':item['name'],'points':item['points'],'showBeforeEarned':True,'repeatable':False},item['id'])
    achievement_ids[item['suffix']] = resource_id
    localizations = asc('achievements','localizations','list','--achievement-id',resource_id,'--paginate')['data']
    loc = next((x for x in localizations if x['attributes']['locale'] == LOCALE),None)
    if loc is None:
        loc = mutate('achievements','localizations','create','--achievement-id',resource_id,'--locale',LOCALE,'--name',item['name'],'--before-earned-description',item['beforeEarnedDescription'],'--after-earned-description',item['afterEarnedDescription'])['data']
    expected = {key:item[key] for key in ['name','beforeEarnedDescription','afterEarnedDescription']}
    matches(loc['attributes'],expected,item['id']+' localization')
    artwork = image_for('achievements',loc['id'],item['image'])
    versions = asc('achievements','v2','versions','list','--achievement-id',resource_id)['data']
    states = [v['attributes']['state'] for v in versions]
    if not states or any(s != 'PREPARE_FOR_SUBMISSION' for s in states):
        raise RuntimeError(f"Unexpected publication state {item['id']}: {states}")
    releases = asc('achievements','releases','list','--achievement-id',resource_id)['data']
    if releases:
        raise RuntimeError(f"Unexpected release records for {item['id']}")
    report['achievements'].append({'id':resource_id,'vendorId':item['id'],'points':item['points'],'localizationId':loc['id'],'image':artwork,'versions':[{'id':v['id'],**v['attributes']} for v in versions],'releaseCount':len(releases)})
    print(f"Verified achievement: {item['name']}",flush=True)

existing = {r['attributes']['vendorIdentifier']:r for r in asc('leaderboards','list','--app',APP,'--paginate')['data']}
for item in CATALOG['leaderboards']:
    remote = existing.get(item['id'])
    if remote is None:
        remote = mutate('leaderboards','create','--app',APP,'--reference-name',item['name'],'--vendor-id',item['id'],'--formatter',item['formatter'],'--sort',item['sort'],'--submission-type',item['submissionType'],'--score-range-start',item['scoreRangeStart'],'--score-range-end',item['scoreRangeEnd'])['data']
    resource_id = remote['id']
    matches(remote['attributes'],{'referenceName':item['name'],'defaultFormatter':item['formatter'],'scoreSortType':item['sort'],'submissionType':item['submissionType'],'scoreRangeStart':str(item['scoreRangeStart']),'scoreRangeEnd':str(item['scoreRangeEnd'])},item['id'])
    leaderboard_ids[item['suffix']] = resource_id
    localizations = asc('leaderboards','localizations','list','--leaderboard-id',resource_id,'--paginate')['data']
    loc = next((x for x in localizations if x['attributes']['locale'] == LOCALE),None)
    if loc is None:
        loc = mutate('leaderboards','localizations','create','--leaderboard-id',resource_id,'--locale',LOCALE,'--name',item['name'],'--description',item['description'],'--formatter-suffix',item['formatterSuffix'],'--formatter-suffix-singular',item['formatterSuffixSingular'])['data']
    matches(loc['attributes'],{key:item[key] for key in ['name','description','formatterSuffix','formatterSuffixSingular']},item['id']+' localization')
    versions = asc('leaderboards','v2','versions','list','--leaderboard-id',resource_id)['data']
    states = [v['attributes']['state'] for v in versions]
    if not states or any(s != 'PREPARE_FOR_SUBMISSION' for s in states):
        raise RuntimeError(f"Unexpected publication state {item['id']}: {states}")
    releases = asc('leaderboards','releases','list','--leaderboard-id',resource_id)['data']
    if releases:
        raise RuntimeError(f"Unexpected release records for {item['id']}")
    report['leaderboards'].append({'id':resource_id,'vendorId':item['id'],'configuration':remote['attributes'],'localizationId':loc['id'],'versions':[{'id':v['id'],**v['attributes']} for v in versions],'releaseCount':len(releases)})
    print(f"Verified leaderboard: {item['name']}",flush=True)

default_query = urlencode({'include':'defaultLeaderboard','fields[gameCenterDetails]':'defaultLeaderboard'})
detail = apple_api(f"/v1/gameCenterDetails/{CATALOG['gameCenterDetailId']}?{default_query}")['data']
default_board = detail['relationships']['defaultLeaderboard'].get('data') or {}
matches(default_board,{'id':leaderboard_ids[CATALOG['defaultLeaderboard']]},'Default leaderboard')
report['defaultLeaderboardId'] = default_board['id']

existing = {r['attributes']['vendorIdentifier']:r for r in asc('activities','list','--app',APP,'--paginate')['data']}
for item in CATALOG['activities']:
    remote = existing.get(item['id'])
    if remote is None:
        # Separate version creation avoids asc's invalid inline local-id payload.
        remote = mutate('activities','create','--app',APP,'--reference-name',item['name'],'--vendor-id',item['id'],'--min-players',1,'--max-players',1,'--supports-party-code','false','--play-style','ASYNCHRONOUS','--create-initial-version','false')['data']
    resource_id = remote['id']
    matches(remote['attributes'],{'referenceName':item['name'],'minimumPlayersCount':1,'maximumPlayersCount':1,'playStyle':'ASYNCHRONOUS'},item['id'])
    versions = asc('activities','versions','list','--activity-id',resource_id)['data']
    if not versions:
        versions = [mutate('activities','versions','create','--activity-id',resource_id)['data']]
    if len(versions) != 1 or versions[0]['attributes']['state'] != 'PREPARE_FOR_SUBMISSION':
        raise RuntimeError(f"Unexpected activity versions for {item['id']}")
    version = versions[0]
    localizations = asc('activities','localizations','list','--version-id',version['id'],'--paginate')['data']
    loc = next((x for x in localizations if x['attributes']['locale'] == LOCALE),None)
    if loc is None:
        loc = mutate('activities','localizations','create','--version-id',version['id'],'--locale',LOCALE,'--name',item['name'],'--description',item['description'])['data']
    matches(loc['attributes'],{key:item[key] for key in ['name','description']},item['id']+' localization')
    artwork = image_for('activities',loc['id'],item['image'])
    default_artwork = default_activity_image(version['id'],item['image'])
    if not args.verify_only:
        for group,ids in [('achievements',achievement_ids),('leaderboards',leaderboard_ids)]:
            linked = [ids[suffix] for suffix in item[group]]
            mutate('activities',group,'set','--activity-id',resource_id,'--ids',','.join(linked))
            report['relationshipWrites'].append({'activityId':resource_id,'type':group,'ids':linked,'result':'API accepted'})
    confirmed = read_activity_with_relationships(resource_id)
    matches(confirmed['attributes'],{'supportsPartyCode':False},item['id'])
    associations = {}
    for group,ids in [('achievements',achievement_ids),('leaderboards',leaderboard_ids)]:
        actual = sorted(x['id'] for x in confirmed['relationships'][group]['data'])
        expected = sorted(ids[suffix] for suffix in item[group])
        if actual != expected:
            raise RuntimeError(f"Activity association mismatch for {item['id']}: {group}")
        associations[group] = actual
    report['activities'].append({'id':resource_id,'vendorId':item['id'],'configuration':confirmed['attributes'],'localizationId':loc['id'],'image':artwork,'defaultImage':default_artwork,'versions':[{'id':v['id'],**v['attributes']} for v in versions],'verifiedRelationships':associations})
    print(f"Verified activity: {item['name']}",flush=True)

activity_releases = asc('activities','releases','list','--app',APP,'--paginate')['data']
if activity_releases:
    raise RuntimeError('Unexpected activity release records')
report['activityReleaseCount'] = 0
report['totalAchievementPoints'] = sum(x['points'] for x in CATALOG['achievements'])
report['verificationLimits'] = ['Checks metadata, image delivery, version states, activity associations and absent releases via live API. Does not prove authenticated device gameplay.']
report['verifiedAt'] = datetime.now(timezone.utc).isoformat()
output = ROOT / ('verification.json' if args.verify_only else 'staging.json')
output.write_text(json.dumps(report,indent=2)+'\n')
print(f'Saved {output}. All 20 components remain PREPARE_FOR_SUBMISSION; no releases created.',flush=True)
