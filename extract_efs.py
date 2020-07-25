import sys
import os
import re
if len(sys.argv)!=3:
	print("Usage: "+sys.argv[0]+" <file> <directory>")
	sys.exit()
f=open(sys.argv[1],"r")
file=f.read()
f.close()
os.system("mkdir "+sys.argv[2])
heads = file.split("------------------------------------------------------------------------------") 
i=0
while i<len(heads):
	params = {}
	params_raw = heads[i].split("\x0a") 
	for j in params_raw:
		if len(j.split("="))==2:
			params.update({j.split("=")[0]:j.split("=")[1]})
		if params.has_key(".mode") and params.has_key("name"):
			if params[".mode"].find("d")!=-1:
				directory=params["name"].replace('"','').replace("\r","")
				print("mkdir %s"%directory)
				os.system("mkdir -p %s/%s"%(sys.argv[2],directory))
			else:
				file_name=params["name"].replace('"','').replace("\r","") 
				dump = heads[i+1].split("data",1)[1]
				lines = dump.split("\n")
				dump_hex = ""	
				for k in lines:	
					try:
						clear_line = k.split(":",1)[1].split("  ",1)[0]
						raw_line = clear_line.replace(" ","\\x") 
						dump_hex += raw_line
						dump_raw = eval('"%s"'%dump_hex)
					except:
						pass
				print("%s/%s/%s"%(sys.argv[2],directory,file_name))
				f2=open("%s/%s/%s"%(sys.argv[2],directory,file_name),"w")
				f2.write(dump_raw)
				f2.close()
	i+=1
