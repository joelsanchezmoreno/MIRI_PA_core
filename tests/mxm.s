///////DELETE COMMENTS IN ORDER TO PARSE THIS CODE////////
$0 0
$1 a addr
$2 b addr
$3 c addr
$4 i
$5 j
$6 k
$7 128
$8 i+j*128
$9 i+k*128
$10 k+j*128
$11 a[i][k]
$12 b[k][j]
$13 c[i][j]
$14 a[i][k]*b[k][j]

ADDI $1,$1,0	//@a	= 0			0x00
ADDI $2,$2,512	//@b	= 512			0x04
ADDI $3,$3,1024 //@c	= 1024			0x08
ADDI $4,$4,0	//i	= 0			0x0C
ADDI $5,$5,0	//j	= 0			0x10
ADDI $6,$6,0	//k	= 0			0x14
ADDI $7,$7,0	//$7	= 128			0x18
I_LOOP: J_LOOP: MUL $8,$5,$7	//j * 128	0x1C
ADD $8,$8,$4    //i + j * 128			0x20
ADD $3,$3,$8	//@c 	= i + j * 128		0x24
STW $0,0($3)    //c[i][j] = 0			0x28
LDW $13,0($3)   //$13	= c[i][j]		0x2C
K_LOOP: MUL $9,$6,$7	//k * 128 		0x30
ADD $9,$9,$4	//i + k * 128			0x34
ADD $1,$1,$9	//@a	= i + k * 128		0x38
LDW $11,0($1)   //$11	= a[i][k]		0x3C
MUL $10,$5,$7	//j * 128			0x48
ADD $10,$10,$6	//k + j * 128			0x4C
ADD $2,$2,$10	//@b	=			0x50
LDW $12,0($2)   //$12	= b[k][j]		0x54
MUL $14,$11,$12 //$14	= a[i][k]*b[k][j]	0x58
ADD $13,$13,$14 //$13 	= $13 + a[i][k]*b[k][j]	0x5C
ADDI $6,$6,1	//k++				0x60
BLT &6,&7, K_LOOP //				0x64
STW $13,0($3)	//c[i][j]= $13			0x68
ADDI $5,$5,1	//j++				0x6C
BLT &5,&7, J_LOOP //				0x70
ADDI $4,$4,1	//i++				0x74
BLT $4,$7, I_LOOP //				0x78


int main() {
	int a[128][128], b[128][128], c[128][128];
	
	int i, j, k;
	for(i = 0 ; i < 128; i++) {
		for(j = 0; j < 128; j++) {
			c[i][j] = 0;
			for(k = 0; k < 128; k++)
				c[i][j] = c[i][j] + a[i][k]*b[k][j];
		}	
	}
}
//////////////////////////////////////////////////////
ADDI $1,$1,0
ADDI $2,$2,512
ADDI $3,$3,1024
ADDI $4,$4,0
ADDI $5,$5,0
ADDI $6,$6,0
ADDI $7,$7,0
MUL $8,$5,$7
ADD $8,$8,$4
ADD $3,$3,$8
STW $0,0($3)
LDW $13,0($3)
MUL $9,$6,$7
ADD $9,$9,$4
ADD $1,$1,$9
LDW $11,0($1)
MUL $10,$5,$7
ADD $10,$10,$6
ADD $2,$2,$10
LDW $12,0($2)
MUL $14,$11,$12
ADD $13,$13,$14
ADDI $6,$6,1
BLT &6,&7,48
STW $13,0($3)
ADDI $5,$5,1
BLT &5,&7,28
ADDI $4,$4,1
BLT $4,$7,28
