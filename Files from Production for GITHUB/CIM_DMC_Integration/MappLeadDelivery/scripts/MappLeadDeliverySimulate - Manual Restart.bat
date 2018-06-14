@echo off

echo script start

set INPUT_FILE_NAME="\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\E_AD_SS_398_299_100418_VIC IEWelcmeAPR18_1000jskn4d3m1000jt4t23mx1000jt8b91fm20180410.csv"
echo INPUT_FILE_NAME "\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\E_AD_SS_398_299_100418_VIC IEWelcmeAPR18_1000jskn4d3m1000jt4t23mx1000jt8b91fm20180410.csv"
set TRM_TEMPLATE_ID=1000jt4t23mx
echo TRM_TEMPLATE_ID 1000jt4t23mx

set TRM_COMMUNICATION_ID=1000jskn4d3m
echo TRM_COMMUNICATION_ID 1000jskn4d3m

set TRM_RUN_ID=1000jt8b91fm
echo TRM_RUN_ID 1000jt8b91fm

echo translate start

java -Xms256M -Xmx512M -XX:-UseGCOverheadLimit -XX:+UseConcMarkSweepGC -cp D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/MappLeadDelivery.jar;D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/lib/* teradata.com.cim.tools.dmc.ControlXMLGenerate ^
-configFile=D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/config/MappLeadDelivery.properties ^
-inputFile="\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\E_AD_SS_398_299_100418_VIC IEWelcmeAPR18_1000jskn4d3m1000jt4t23mx1000jt8b91fm20180410.csv" ^
-workingPath=D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\working ^
-archivePath=\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\MappLeadDelivery\\archive ^
-failedPath=\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\MappLeadDelivery\\failed ^
-templateId=1000jt4t23mx ^
-communicationId=1000jskn4d3m ^
-cimRunId=1000jt8b91fm ^
-simulate=false

pause
echo translate end

echo script end
