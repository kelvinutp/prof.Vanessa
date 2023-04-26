import re
import sys
import subprocess as sb

def format_ids(a):
    '''
    reads ids and gives them a xx-xxxx-xxxxxx format


    '''
    p_id=r'([0-9A-Z]*)-([0-9]*)-([0-9]*)'
    f_id=[0,2,4,6]
    ids=[]

    for b in a:
        c=re.search(p_id,b)
        if c==None:
            continue
        else:
            z=''
            for d in range(1,4):
                if len(c[d])==f_id[d]:
                    z=z+c[d]+'-'
                else:
                    z=z+'0'*(f_id[d]-len(c[d]))+c[d]+'-'
            ids.append(z[:-1])
    return ids

if __name__=="__main__":
    print("Introduzca las cedula, al terminar presione CTRL+Z y enter")
    a=sys.stdin.readlines()
    b=format_ids(a)
    for c in b:
        print(c)
    sb.run('clip',text=True,input='\n'.join(b))