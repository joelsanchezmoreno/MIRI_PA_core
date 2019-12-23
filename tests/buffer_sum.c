int main() {
	int a[128], sum = 0;
	int i;
	for(i = 0; i < 128; i++) a[i] = i;
	for(i = 0; i < 128; i++) sum += a[i];
}
