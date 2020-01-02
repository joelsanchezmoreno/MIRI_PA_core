///////DELETE COMMENTS IN ORDER TO PARSE THIS CODE////////
//$1 sum
//$2 a addr
//$3 i
//$4 128
//$5 a[i]
ADDI $1,$1,0   //sum  = 0    0x00
ADDI $2,$2,0   //@a   = 0    0x04
ADDI $3,$3,0   //i    = 0    0x08
ADDI $4,$4,128 //$4   = 128  0x0C
STW $3,0($2)   //a[i] = i    0x10
ADDI $2,$2,4   //@a  += 4    0x14
ADDI $3,$3,1   //i   += 1    0x18
BLT $3,$4,16   //i   <  128? 0x1C
ADDI $3,$3,0   //i    = 0    0x20
ADDI $2,$2,0   //@a   = 0    0x24
LDW $5,0($2)   //$5   = a[i] 0x28
ADD $1,$1,$5   //sum += a[i] 0x2C
ADDI $2,$2,4   //@a  += 4    0x30
ADDI $3,$3,1   //i   += 1    0x34
BLT $3,$4,40   //i    < 128? 0x38


int main() {
	int a[128], sum = 0;
	int i;
	for(i = 0; i < 128; i++) a[i] = i;
	for(i = 0; i < 128; i++) sum += a[i];
}
//////////////////////////////////////////////////////
ADDI $1,$1,0
ADDI $2,$2,0
ADDI $3,$3,0
ADDI $4,$4,128
STW $3,0($2)
ADDI $2,$2,4
ADDI $3,$3,1
BLT $3,$4,16
ADDI $3,$3,0
ADDI $2,$2,0
LDW $5,0($2)
ADD $1,$1,$5
ADDI $2,$2,4
ADDI $3,$3,1
BLT $3,$4,40
