rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist\outputs"
set wdir=%CD%
 
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET CURRTM=%SYSHH%%SYSMI%

rem pad timestamp if the first char is emtpy
if "%CURRTM:~0,1%"==" " SET CURRTM=0%CURRTM:~1,5%
	
mkdir %TRM_TPLT%
copy addHeaderRussia.sql "%wdir%\%TRM_TPLT%\addHeader%CURRTM%.sql"
copy addHeaderRussia.tmp "%wdir%\%TRM_TPLT%\addHeader%CURRTM%.tmp"
cd %TRM_TPLT%

..\ssr.exe 0 $TRM_TPLT %TRM_TPLT% addHeader%CURRTM%.sql addHeader%CURRTM%%.tmp

rem Header Row save in File

bteq < addHeader%CURRTM%.tmp > HeaderRow%CURRTM%.log

rem Files concatenate
FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
   copy "Headerrow%TRM_TPLT%.tmp" + "%%i" newfile.txt
   DEL /Q "%%i"
   copy newfile.txt "%%i"
   DEL newfile.txt
)