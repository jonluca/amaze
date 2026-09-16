#!/usr/bin/env python3
"""Generate ASC metadata from the checked-in Swift catalog (no authentication required)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT.parent / 'PrismRoll' / 'Core'
text = (CORE / 'GameCenterAchievement.swift').read_text()
raw = dict(re.findall(r'case (\w+) = "([^\"]+)"', text))

def values(property_name):
    body = re.search(r'var ' + property_name + r': \w+ \{(.*?)\n    \}', text, re.S).group(1)
    result = {}
    for cases,value in re.findall(r'case ([^:]+): ("[^\"]*"|\d+)', body):
        for case in re.findall(r'\.(\w+)', cases):
            result[case] = json.loads(value)
    return result

properties = {name: values(name) for name in ['title','points','target','unachievedDescription','achievedDescription']}
achievements = [dict(suffix=suffix,id=f'com.jonluca.prismroll.achievement.{suffix}',name=properties['title'][case],points=properties['points'][case],target=properties['target'][case],beforeEarnedDescription=properties['unachievedDescription'][case],afterEarnedDescription=properties['achievedDescription'][case],showBeforeEarned=True,repeatable=False,image=f'artwork/{suffix}.png') for case,suffix in raw.items()]

boards = [
    ('classic_completed','Classic Mazes Completed','Different Classic mazes completed.'),
    ('perfect_completed','Perfect Mazes','Different regular levels completed with a Perfect solve.'),
    ('limited_completed','Limited Moves Completed','Different Limited Moves levels completed.'),
    ('rush_completed','Time Rush Completed','Different Time Rush rounds completed.'),
    ('daily_completed','Daily Mazes Completed','Different daily mazes completed.')]
leaderboards = [dict(suffix=suffix,id=f'com.jonluca.prismroll.leaderboard.{suffix}',name=name,description=description,formatter='INTEGER',sort='DESC',submissionType='BEST_SCORE',recurring=False,scoreRangeStart=0,scoreRangeEnd=2147483647,formatterSuffix='mazes',formatterSuffixSingular='maze') for suffix,name,description in boards]

activities = [
    dict(suffix='classic', name='Classic Mazes',description='Follow the color. Find your flow in a Classic maze.',leaderboards=['classic_completed','perfect_completed'],achievements=['first_maze','classic_25','classic_100','classic_500','perfect_1','perfect_25','perfect_100']),
    dict(suffix='time_rush',name='Time Rush',description='Beat the clock and fill every path before time runs out.',leaderboards=['rush_completed'],achievements=['rush_10']),
    dict(suffix='daily',name='Daily Maze',description='A fresh maze every day. Roll in and make it yours.',leaderboards=['daily_completed'],achievements=['daily_1','daily_7'])]
for item in activities:
    item.update(id=f"com.jonluca.prismroll.activity.{item['suffix']}",minimumPlayers=1,maximumPlayers=1,supportsPartyCode=False,playStyle='ASYNCHRONOUS',image=f"artwork/activity_{item['suffix']}.png")
manifest = dict(schemaVersion=1,appId='6809253424',bundleId='com.jonluca.prismroll',gameCenterDetailId='c19f1a60-288d-4cfd-8fba-9fdf3fe8cb58',locale='en-US',defaultLeaderboard='classic_completed',publicationPolicy='Stage only. Do not create releases or submit for review.',achievements=achievements,leaderboards=leaderboards,activities=activities)
assert sum(x['points'] for x in achievements) == 550
(ROOT / 'catalog.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Wrote 12 achievements (550 points), 5 leaderboards, 3 activities')
