import os
file1_root = os.path.abspath(r'C:\Tests\Task2\file1.txt')
file1_read = str(open('file1.txt', 'r').read())
file2_root = os.path.abspath(r'C:\Tests\Task2\file2.txt')
file2_read = str(open('file2.txt', 'r').read())
def file1_coor(file1_read):
    i=0
    x=''
    y=''
    r=''
    file1_coor=[]
    for f in file1_read:
        if not f.isspace() and i==0:
            x+=str(f)
        elif f.isspace() and i==0:
            file1_coor.append(x)
            i+=1
        elif not f.isspace() and i==1:
            y+=str(f)
        elif f=='\n' and i==1:
            file1_coor.append(y)
            i+=1
        elif not f.isspace() and i==2:
            i+=1
            r+=f
            file1_coor.append(r)
        elif not f.isspace() and i==3:
            file1_coor[2]+=f
        else:
            continue
    return file1_coor
def file2_coor(file2_read):
    i=0
    j=0
    a=''
    file2=[]
    file2_coor=[]
    for f in file2_read:
        if not f=='\n' and i==j:
            file2_coor.append(f)
            i+=1
        elif not f=='\n' and i>j:
            file2_coor[j]+=str(f)
        elif f=='\n':
            j+=1
    return file2_coor
def result(f1, f2):
    if len(f2)>=1 and len(f2)<=100:
        f1x = float(f1[0])
        f1y = float(f1[1])
        f1r = int(f1[2])
        i=1
        for coor in f2:
            j=0
            x=''
            y=''
            for f in coor:
                    if f.isdigit() and j==0:
                        x+=f
                    elif f.isdigit() and j==1:
                        y+=f
                    elif f==' ':
                        j+=1
            x=float(x)
            y=float(y)
            i+=1
            math = (x - f1x)**2 / f1r**2 + (y - f1y)**2 / f1r**2
            if math < 1:
                print(1)
            elif math == 1:
                print(0)
            else:
                print(2)
result(file1_coor(file1_read), file2_coor(file2_read))