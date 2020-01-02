///////DELETE COMMENTS IN ORDER TO PARSE THIS CODE////////
//$2 a addr
//$3 i
//$4 128
//$5 a[i]
//$7 5
//$8 b addr
ADDI $2,$2,0   //@a   = 0     0x00
ADDI $3,$3,0   //i    = 0     0x04
ADDI $4,$4,128 //$4   = 128   0x08
ADDI $7,$7,5   //$7   = 5     0x0C
STW $7,0($2)   //a[i] = 5     0x10
ADDI $2,$2,4   //@a  += 4     0x14
ADDI $3,$3,1   //i   += 1     0x18
BLT $3,$4,16   //i   <  128?  0x1C
ADDI $3,$3,0   //i    = 0     0x20
ADDI $2,$2,0   //@a   = 0     0x24
ADDI $8,$8,512 //@b   = 4*128 0x28
LDW $5,0($2)   //$5   = a[i]  0x2C
STW $5,0($8)   //b[i] = $5    0x30
ADDI $2,$2,4   //@a  += 4     0x34
ADDI $8,$8,4   //@b  += 4     0x38
ADDI $3,$3,1   //i   += 1     0x3C
BEQ $3,$4,44   //i    < 128?  0x40

int main() {
        int a[128], b[128];
        int i;
        for(i = 0; i < 128; i++) a[i] = 5;
        for(i = 0; i < 128; i++) b[i] = a[i];
}
//////////////////////////////////////////////////////
ADDI $2,$2,0
ADDI $3,$3,0
ADDI $4,$4,128
ADDI $7,$7,5
STW $7,0($2)
ADDI $2,$2,4
ADDI $3,$3,1
BLT $3,$4,16
ADDI $3,$3,0
ADDI $2,$2,0
ADDI $8,$8,512
LDW $5,0($2) 
STW $5,0($8)
ADDI $2,$2,4
ADDI $8,$8,4
ADDI $3,$3,1
BEQ $3,$4,44
