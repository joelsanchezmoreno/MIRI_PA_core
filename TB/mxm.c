int main() {
	int a[128][128], b[128][128], c[128][128];
	
	int i, j, k;
	for(i = 0 ; i < 128; i++) {
		for(j = 0; j < 128; j++) {
			c[i][j] = 0;
			for(k = 0; k < 128; k++)
				c[i][j] = c[i][j] + a[i][k]*b[k][j];
		}	
	};
}
