import os
#file_path = 'C:\\Users\\kotho\\Documents\\GitHub\\Tasks\\Task4\\file.txt'
file_path = input('File path = ')
file_root = os.path.abspath(file_path)
file_read = str(open('file.txt', 'r').read())
def mass(f):
    mass=[]
    i=0
    j=0
    for dif in file_read:
        for f in dif:
            if f.isdigit() and i==0:
                mass.append(f)
                i+=1
            elif f.isdigit() and i==1:
                mass[j]+=str(f)
            elif f.isspace():
                i=0
                j+=1
    return mass
def count(mass):
    i=0
    sum=0
    while i<len(mass):
        sum+=int(mass[i])
        i+=1
    return (sum // len(mass))
def eqi(mass, count):
    i=0
    mass_c=[]
    while i<len(mass):
        mass_c.append(count)
        i+=1
    return mass_c
def result(mass, mass_c):
    i=0
    j=0
    count=0
    while mass!=mass_c:
        m1=int(mass[j])
        m2=int(mass_c[j])
        if m1!=m2 and m1<m2:
            m1+=1
            mass[j]=m1
            count+=1
        elif m1!=m2 and m1>m2:
            m1-=1
            mass[j]=m1
            count+=1
        elif m1==m2:
            j+=1
    return count
print(result(mass(file_read), eqi(mass(file_read), count(mass(file_read)))))