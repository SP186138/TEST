D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist\"
set wdir=%CD%
 
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET CURRTM=%SYSHH%%SYSMI%

rem Run the Derived Responses jobs   
cmd /c "%wdir%\DerivedResponsejobs.bat"
rem Run the Intraday Batch job
cmd /c "%wdir%\IntradaySubmit.bat" 
  