rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist"
set wdir=%CD%
 
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET CURRTM=%SYSHH%%SYSMI%

rem pad timestamp if the first char is emtpy
if "%CURRTM:~0,1%"==" " SET CURRTM=0%CURRTM:~1,5%
	
rem Files concatenate
FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
   java -jar DMCRussiaUpload.jar "%1" "%%i"
)