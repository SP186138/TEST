@echo off

echo script start

set INPUT_FILE_NAME="\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\NL_AD_SS_115_070518_PGE Walgreens May_1000jvz8hcl11000jxbhf47f1000jxbhl2gv20180510.csv"
echo INPUT_FILE_NAME "\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\NL_AD_SS_115_070518_PGE Walgreens May_1000jvz8hcl11000jxbhf47f1000jxbhl2gv20180510.csv"
set TRM_TEMPLATE_ID=1000jxbhf47f
echo TRM_TEMPLATE_ID 1000jxbhf47f

set TRM_COMMUNICATION_ID=1000jvz8hcl1
echo TRM_COMMUNICATION_ID 1000jvz8hcl1

set TRM_RUN_ID=1000jxbhl2gv
echo TRM_RUN_ID 1000jxbhl2gv

echo translate start

javaw -Xms256M -Xmx512M -XX:-UseGCOverheadLimit -XX:+UseConcMarkSweepGC -cp D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/MappLeadDelivery.jar;D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/lib/* teradata.com.cim.tools.dmc.ControlXMLGenerate ^
-configFile=D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/config/MappLeadDelivery.properties ^
-inputFile="\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\NL_AD_SS_115_070518_PGE Walgreens May_1000jvz8hcl11000jxbhf47f1000jxbhl2gv20180510.csv" ^
-workingPath=D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\working ^
-archivePath=\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\MappLeadDelivery\\archive ^
-failedPath=\\\\VA1UCPZLAP1CP04.va1.savvis.net\\Icrm\\outbound\\Customer_Service1789\\Extracts\\CEP\\MappLeadDelivery\\failed ^
-templateId=1000jxbhf47f ^
-communicationId=1000jvz8hcl1 ^
-cimRunId=1000jxbhl2gv ^
-simulate=false

pause
echo translate end

echo script end
