@echo off

echo script start

echo TRM_MANIFEST_FILE %TRM_MANIFEST_FILE%
echo TRM_COM %TRM_COM%
echo TRM_CNAME %TRM_CNAME%
echo TRM_TPLT %TRM_TPLT%
echo TRM_TNAME %TRM_TNAME%

echo TRM_USER %TRM_USER%
echo TRM_RUN %TRM_RUN%

set /p INPUT_FILE_NAME=<"%TRM_MANIFEST_FILE%"

echo INPUT_FILE_NAME %INPUT_FILE_NAME%

echo translate start

javaw -Xms256M -Xmx512M -XX:-UseGCOverheadLimit -XX:+UseConcMarkSweepGC -cp D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/MappLeadDelivery.jar;D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/lib/* teradata.com.cim.tools.dmc.ControlXMLGenerate ^
-configFile=D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/config/MappLeadDelivery.properties ^
-inputFile="%INPUT_FILE_NAME%" ^
-workingPath=D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\working ^
-archivePath=\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\MappLeadDelivery\\archive ^
-failedPath=\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\MappLeadDelivery\\failed ^
-templateId=%TRM_TPLT% ^
-communicationId=%TRM_COM% ^
-cimRunId=%TRM_RUN% ^
-simulate=false

echo translate end

echo script end
