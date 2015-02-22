import sys, os, re, math
from string import strip


def main_work():
	xformfile = sys.argv[1]
	k = float(sys.argv[2])
	f = open(xformfile)
	xform_lines = f.readlines()
	f.close()
	
	i=0
	
	while i < len(xform_lines):
		field =  xform_lines[i].split(' ')
		if "<XFORM>" == field[0]:
			print xform_lines[i].split('\n')[0]
			n=int(field[2].split('\n')[0])				
			for p in range (0, n):
				i = i + 1
				field = xform_lines[i].split()
				#print xform_lines[i].split('\n')[0]
				
				for j in range(0,n):
					if p == j:
						print k * float(field[j]) + (1-k),
					else:
						print k * float(field[j]),
				print
		else:
			if "<BIAS>" == field[0]:
				print xform_lines[i].split('\n')[0]
				n = int(field[1].split('\n')[0])
				i = i+1
				
				field = xform_lines[i].split()
#				print field
				for j in range (0, n):
					print k * float(field[j]), #xform_lines[++i].split('\n')[0]
				print	
			else:
				print xform_lines[i].split('\n')[0]
		i = i+1			
		
if __name__=="__main__":
	main_work()
