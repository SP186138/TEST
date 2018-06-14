@echo off

echo script start

set INPUT_FILE_NAME="D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\O_AD_SS_277_051217_20171205_BE_4695_Pa_1000jkj3195z1000jkj31grc1000jq5xwmbx20180316.csv"
echo INPUT_FILE_NAME "D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\O_AD_SS_277_051217_20171205_BE_4695_Pa_1000jkj3195z1000jkj31grc1000jq5xwmbx20180316.csv"
set TRM_TEMPLATE_ID=1000jkj313g6
echo TRM_TEMPLATE_ID 1000jkj313g6

set TRM_COMMUNICATION_ID=1000jkj3108q
echo TRM_COMMUNICATION_ID 1000jkj3108q

set TRM_RUN_ID=1000jq5xwm3v
echo TRM_RUN_ID 1000jq5xwm3v

echo translate start

java -cp D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/MappLeadDelivery.jar;D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/lib/* teradata.com.cim.tools.dmc.ControlXMLGenerate ^
-configFile=D:/CIM10/CIM_DMC_Integration/MappLeadDelivery/config/MappLeadDelivery.properties ^
-inputFile="D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\O_AD_SS_277_051217_20171205_BE_4695_Pa_1000jkj3195z1000jkj31grc1000jq5xwmbx20180316.csv" ^
-workingPath=D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\working ^
-archivePath=D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\archive ^
-failedPath=D:\\CIM10\\CIM_DMC_Integration\\MappLeadDelivery\\failed ^
-templateId=1000jkj31grc ^
-communicationId=1000jkj3195z ^
-cimRunId=1000jq5xwmbx ^
-simulate=true

pause
echo translate end

echo script end
