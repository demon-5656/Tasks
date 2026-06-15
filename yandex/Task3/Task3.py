import os, json
tests_path = 'C:\\Users\\kotho\\Documents\\GitHub\\Tasks\\Task3\\tests.json'
#tests_path = input('tests path = ')
tests_root = os.path.abspath(tests_path)
tests_read = str(open('%s' %tests_path, 'r').read())
tests_json = json.loads(tests_read)
values_path = 'C:\\Users\\kotho\\Documents\\GitHub\\Tasks\\Task3\\values.json'
#values_path = input('values path = ')
values_root = os.path.abspath(values_path)
values_read = str(open('%s' %values_root, 'r').read())
values_json = json.loads(values_read)
tests_mass=[]
values_mass=[]
for section1, commands1 in tests_json.items():
    for c1 in  commands1:
        print(c1)
for section2, commands2 in values_json.items():
    for c2 in  commands2:
        print(c2)
print(tests_mass)
print(values_mass)