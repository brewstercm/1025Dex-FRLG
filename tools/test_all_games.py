"""Run all eleven schema/encounter/Hoennto tests against supplied sources.
Usage: python tools/test_all_games.py ENGINE_SOURCE HOENNTO_SOURCE [GAME ...]
Requires lupa's Lua 5.3 runtime.
"""
import os
import sys
from pathlib import Path
from lupa.lua53 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BIT_SETUP = "package.preload.bit=function() local function u(x)return math.floor(x) & 0xffffffff end;local b={}; b.band=function(a,...)local n=u(a);for _,v in ipairs({...})do n=n & u(v)end;return n end;b.bor=function(a,...)local n=u(a);for _,v in ipairs({...})do n=n | u(v)end;return n end;b.bxor=function(a,...)local n=u(a);for _,v in ipairs({...})do n=n ~ u(v)end;return n end;b.bnot=function(a)return u(~u(a))end;b.lshift=function(a,n)return u(u(a) << (n%32))end;b.rshift=function(a,n)return u(a) >> (n%32)end;b.arshift=function(a,n)local x=u(a);if x>=0x80000000 then x=x-0x100000000 end;return u(x >> (n%32))end; b.tobit=function(x) x=b.band(x,0xffffffff);return x>=0x80000000 and x-0x100000000 or x end; b.tohex=function(x,n)return string.format('%08x',b.band(x,0xffffffff))end;return b end"

if __name__ == '__main__':
    engine = Path(sys.argv[1]).resolve()
    hoennto = Path(sys.argv[2]).resolve()
    games = sys.argv[3:] or ['red','blue','yellow','gold','silver','crystal','ruby','sapphire','firered','leafgreen','emerald']
    source = (ROOT / 'tests/all_games.lua').read_text(encoding='utf-8')
    os.chdir(engine)
    for game in games:
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(BIT_SETUP)
        lua.globals().arg = lua.table_from([str(ROOT), game, str(hoennto)])
        lua.execute(source)
