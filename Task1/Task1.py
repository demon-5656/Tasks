n=int(input('Введите n = '))
m=int(input('Введите m = '))
def mass_cr(n):
    i=0
    j=1
    mass_les = n-1; mass_les*=n;
    mass=[]
    while len(mass)<=mass_les:
        if j<n:
            mass.append(j)
            j+=1
        elif j==n:
            mass.append(j)
            j=1
        else:
            break
    return mass
def line_cr(m):
    i=0
    l=0
    line=[]
    for j in mass_cr(n):
        if i==0:
            line.append(j)
            i+=1
            l+=m-1
        elif j!=line[0] and i==l:
            line.append(j)
            i+=1
            l+=m-1
        elif j==line[0] and len(line)>1 and i==l:
            break
        else:
            i+=1
            continue
    return line
for i in line_cr(m):
    print(i)