D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist\outputs"
FOR /F "tokens=*" %%G IN ('DIR /AD /B') DO RMDIR %%G  /Q /S
cd ..
FOR /F "tokens=*" %%I IN ('DIR *.tmp,*.log /A:-D /B') DO DEL %%I