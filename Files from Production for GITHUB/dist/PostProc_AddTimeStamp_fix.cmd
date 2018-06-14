rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist"
set wdir=%CD%
 
rem SET SYSTM=%TIME%
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET SYSSS=%SYSTM:~6,2%
SET CURRTM=%SYSHH%%SYSMI%%SYSSS%


rem pad timestamp if the first char is emtpy
if "%CURRTM:~0,1%"==" " SET CURRTM=0%CURRTM:~1,5%
 
FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
   echo off
   find /v "" "%%i" > ~Temp%TRM_TPLT%%CURRTM%.txt      
   for /f "tokens=1,* delims=[]" %%a in (~Temp%TRM_TPLT%%CURRTM%.txt) do set Last=%%a
   type "%%i" | find /v "%Last%" > newfile%TRM_TPLT%%CURRTM%.txt
   echo on
   copy /B newfile%TRM_TPLT%%CURRTM%.txt "\\%%~pi%%~ni%CURRTM%.txt"

   del /Q ~Temp%TRM_TPLT%%CURRTM%.txt
   del /Q newfile%TRM_TPLT%%CURRTM%.txt
   del /Q "%%i"
)
