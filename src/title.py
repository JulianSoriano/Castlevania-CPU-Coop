# Title credits patch: rows 20-23 of the title nametable (RLE stream in bank 6)
H=16
def off(bank,addr): return H+bank*0x4000+(addr-(0xC000 if bank==15 else 0x8000))
ENC={**{c:0xE5+i for i,c in enumerate('ABCDEF')},'H':0xEC,'I':0xED,'K':0xEF,'L':0xF0,'M':0xF1,'N':0xF2,
     'O':0xF3,'P':0xF4,'R':0xF6,'S':0xF7,'T':0xF8,'U':0xF9,'Y':0xFC,' ':0x00,'.':0xEB}
def decode(buf,i,ntiles):
    out=[]
    while len(out)<ntiles:
        b=buf[i]
        if b==0xD4: out+= [buf[i+2]]*buf[i+1]; i+=3
        else: out.append(b); i+=1
    return out,i
def row(text,col):
    r=[0]*32
    for k,c in enumerate(text): r[col+k]=ENC[c]
    return r
def encode(tiles):
    s=[];i=0
    while i<len(tiles):
        j=i
        while j<len(tiles) and tiles[j]==tiles[i]: j+=1
        n=j-i
        if n>=4: s+=[0xD4,n,tiles[i]]
        else: s+=tiles[i:j]
        i=j
    return s
def patch(rom):
    start=off(6,0xB063)
    assert rom[start:start+3]==bytes([0xD4,9,0]), rom[start:start+3].hex()
    old,end=decode(rom,start,128)
    assert rom[end]==0xD9, hex(rom[end])
    L1,L2='COOP MOD BY MATERIASHRINE','CPU MOD BY RAMENPHOLIFE'
    tiles=row('',0)+row(L1,(32-len(L1)+1)//2)+row('',0)+row(L2,(32-len(L2)+1)//2)
    s=encode(tiles); room=end-start
    assert len(s)<=room, (len(s),room)
    # pad to exact length: break the first long zero run into literal zeros
    while len(s)<room:
        k=s.index(0xD4)
        n=s[k+1]
        if n>4: s=s[:k]+[0]+[0xD4,n-1,0]+s[k+3:]
        else: s=s[:k]+[0]*n+s[k+3:]
    assert len(s)==room and decode(bytes(s),0,128)[0]==tiles
    rom[start:end]=bytes(s)
    return old
