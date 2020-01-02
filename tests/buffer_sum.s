///////DELETE COMMENTS IN ORDER TO PARSE THIS CODE////////
//$1 sum
//$2 a addr
//$3 i
//$4 128
//$5 a[i]
ADDI $1,$1,0   //sum  = 0
ADDI $2,$2,0   //@a   = 0
ADDI $3,$3,0   //i    = 0
ADDI $4,$4,128 //$4   = 128
STW $3,0($2)   //a[i] = i
ADDI $2,$2,4   //@a  += 4
ADDI $3,$3,1   //i   += 1
BLT $2,$4,16   //i   <  128?
ADDI $2,$2,0   //i    = 0
ADDI $3,$3,0   //@a   = 0
LDW $5,0($3)   //$5   = a[i]
ADD $1,$1,$5   //sum += a[i]
ADDI $2,$2,4   //@a  += 4
ADDI $3,$3,1   //i   += 1
BEQ $2,$4,36   //i    < 128?


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
BLT $2,$4,16
ADDI $2,$2,0
ADDI $3,$3,0
LDW $5,0($3)
ADD $1,$1,$5
ADDI $2,$2,4
ADDI $3,$3,1
BEQ $2,$4,36
