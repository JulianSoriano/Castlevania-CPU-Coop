H=16
def off(bank,addr): return H+bank*0x4000+(addr-(0xC000 if bank==15 else 0x8000))
LIVES=10   # $2A holds lives+1: HUD shows 09
def patch(rom):
    for bank,base in ((15,0xC000),(7,0x8000)):
        for a in (0xC874,0xC979):
            o=off(bank,a-0xC000+base)
            assert rom[o:o+4]==bytes([0xA9,4,0x85,0x2A]), (bank,hex(a),rom[o:o+4].hex())
            rom[o+1]=LIVES
    o=off(8,0x83B5)
    assert rom[o:o+5]==bytes([0xA9,3,0x8D,0x28,0x60]), rom[o:o+5].hex()
    rom[o+1]=9   # P2 spare lives (shown directly on the HUD)
