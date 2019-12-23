import sys

rtype = {"ADD":"00000000", "SUB":"00000001", "MUL":"00000010","ADDI":"00000011"}
mtype = {"LDB":"00010000", "LDW":"00010001", "STB":00010010, "STW":"00010011", "MOV":"00010100"}
btype = {"BEQ":"00110000", "JUMP":"00110001", "TLBWRITE":"00110010", "IRET":"00110011"}

if __name__== "__main__":
    arg = sys.argv[1]
    fnInput  = open(arg,"r")
    lines = fnInput.readlines()
    output = ""
    for i,l in enumerate(lines):
        print(l)
        inst, args = l.split(" ")
        if inst in rtype.keys():
            rd, ra, rb = args.replace('$', '').split(",")
            output += rtype[inst] + "{0:05b}".format(int(rd)) + "{0:05b}".format(int(ra))+ "{0:05b}".format(int(rb)) + "000000000" + "\n"
        elif inst in mtype.keys():
            if inst == "MOV": #Pel que possa a l'enunciat, el mov nomes s'utilitza per mv rm0 -> rd
                rm0, rd = args.replace('$', '').split(',')
                output += mtype[inst] + "{0:05b}".format(int(rd)) + "00000000000000" + "\n"
            else:
                rd, raOffset = args.replace('$', '').split(",")
                ra, offset = raOffset.replace('(', ',').replace(')','').split(',')
                output += mtype[inst] + "{0:05b}".format(int(rd)) + "{0:05b}".format(int(ra)) + "{0:014b}".format(int(offset)) + "\n"

        elif inst in btype.keys():
                #BEQ
                #JUMP
                if inst == 'IRET':
                    output += btype[inst] + + '000000000000000000000000' + '\n'
                #TLBWRITE
                if inst == 'TLBWRITE':
                    r0, r1 = args.replace('$', '').split(',')
                    output += btype[inst] + '00000' + "{0:05b}".format(int(r0)) + "{0:05b}".format(int(r1)) + '000000000' + '\n' #dtlb 1 itlb 0 how we know it?
        else:
            print("Instruction on line ", i, " not recognised")

    fnInput.close()
    fnOutput = open(arg + ".b","w")
    fnOutput.write(output)
    fnOutput.close()


~                                                                                                                                                                                                           
~                          
