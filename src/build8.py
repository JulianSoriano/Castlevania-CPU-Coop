import sys, subprocess, hashlib, os
sys.path.insert(0,'/root/cv/build')
import title, lives
CC='/root/z/cc65/bin/'
H=16
def off(bank,addr): return H+bank*0x4000+(addr-(0xC000 if bank==15 else 0x8000))
def asm():
    subprocess.run([CC+'ca65','-l','tactics.lst','tactics.s','-o','tactics.o']+os.environ.get('CA65ARGS','').split(),check=True,cwd='/root/cv/build')
    subprocess.run([CC+'ld65','-C','tactics.cfg','-o','tactics.bin','-Ln','tactics.lbl','tactics.o'],check=True,cwd='/root/cv/build')
    lbl={l.split()[2][1:]:int(l.split()[1],16) for l in open('/root/cv/build/tactics.lbl')}
    return open('/root/cv/build/tactics.bin','rb').read(), lbl
RESPAWN=int(os.environ.get('RESPAWN','120'))
def patch_v4(rom):
    # --- spikes: heavy damage instead of instant death (bank 6) ---
    trap=bytes([0xA5,0x45,0x69,0xD0,0xB0,0x02,0xA9,0x00,0x85,0x45,0xA9,0xA0,0x85,0x5B,0x4C,0xC1,0x96])
    def find_after(pat,start,bank=6):
        o=off(bank,start); i=rom.find(bytes(pat),o); assert i>=0; return 0x8000+(i-H-bank*0x4000)
    # The damage routine lives where the old "kill" sequence was ($82EA, 17 bytes),
    # so no graphics data is touched (v4 used $B547, which the intro sky uses).
    a=0x82DB; o=off(6,a)
    orig=bytes([0xAE,0x6C,0x04,0xCA,0xD0,0x06,0x20,0xC1,0x96,0x4C,0xEA,0x82,0x20,0xE5,0xA1,
                0xA9,0x00,0x85,0x44,0x85,0x45,0xA5,0x44,0x85,0x4B,0xA0,0x67,0x84,0x4F,0x20,0x3B,0xA2])
    assert rom[o:o+32]==orig, rom[o:o+32].hex()
    rom[o:o+15]=bytes([0x20,0xEA,0x82,0x4C,0xFB,0x82])+bytes([0xEA]*9)
    rom[o+15:o+32]=trap
    # site B (second trap check)
    b=0xBB75; o=off(6,b)
    assert rom[o:o+10]==bytes([0xA9,0x00,0x85,0x45,0xAE,0x6C,0x04,0xCA,0xD0,0x03]), rom[o:o+10].hex()
    tgt=find_after([0xA6,0x4E,0xE8,0xE0,0x03],b); rel=tgt-(b+7); assert 0<rel<128, rel
    rom[o:o+10]=bytes([0x20,0xEA,0x82,0xA5,0x45,0xD0,rel,0xEA,0xEA,0xEA])
    # (v8: stage select removed - the title menu and new-game start are the original)
    # respawn wait: 600 frames -> 120 frames (P1 in bank 8, P2 in bank 6)
    for o,pat in ((0x20240,[0xA9,0x58,0x8D,0xBC,0x60,0xA9,0x02,0x8D,0xBD,0x60]),(0x1baf3,[0xA9,0x58,0x8D,0x26,0x60,0xA9,0x02,0x8D,0x27,0x60])):
        assert rom[o:o+10]==bytes(pat); rom[o+1]=RESPAWN&255; rom[o+6]=RESPAWN>>8
    # (digit glyphs are loaded into CHR-RAM at run time by the menu code)
def build(out, ai=True):
    rom=bytearray(open('/root/cv/orig.nes','rb').read())
    title.patch(rom); lives.patch(rom); patch_v4(rom)
    if ai:
        code,lbl=asm(); base=0x90E0
        o=off(8,base); assert all(b==0xFF for b in rom[o:o+len(code)]); rom[o:o+len(code)]=code
        # hook: AI_MAIN "JSR movement / JSR combat" -> "JSR TACTICS / NOP x3"
        h=off(8,0x8A2D); assert rom[h:h+6]==bytes([0x20,0x21,0x8B,0x20,0xCD,0x8E]), rom[h:h+6].hex()
        t=base   # TACTICS is the first routine
        rom[h:h+6]=bytes([0x20,t&255,t>>8,0xEA,0xEA,0xEA])
        # shared pickups: "LDA $7E01" at $8930 -> "JSR SYNC"
        y=off(8,0x8930); assert rom[y:y+3]==bytes([0xAD,0x01,0x7E]), rom[y:y+3].hex()
        sy=lbl['SYNC']
        if not os.environ.get('NOSYNC'): rom[y:y+3]=bytes([0x20,sy&255,sy>>8])
        g=off(8,0x8281); assert rom[g:g+6]==bytes([0xAD,0x49,0x60,0x8D,0x8C,0x03]), rom[g:g+6].hex()
        gx=lbl['GHOSTX']
        if not os.environ.get('NOGHOST'): rom[g:g+6]=bytes([0x20,gx&255,gx>>8,0xEA,0xEA,0xEA])
        jw=int(os.environ.get('JW','4'))
        if jw!=2:
            j=off(8,0x8C8E); assert rom[j-1]==0xC9 and rom[j]==2, rom[j-3:j+2].hex(); rom[j]=jw
        print('tactics',len(code),'bytes at $90E0, entry',hex(t))
    open(out,'wb').write(rom)
    print(out, hashlib.md5(rom).hexdigest())
if __name__=='__main__': build(sys.argv[1], ai=(len(sys.argv)<3))
