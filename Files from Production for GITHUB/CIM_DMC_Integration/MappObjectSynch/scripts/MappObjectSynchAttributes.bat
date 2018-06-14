@echo off

echo script start

echo import start

javaw -cp D:/CIM10/CIM_DMC_Integration/MappObjectSynch/MappObjectSynch.jar;D:/CIM10/CIM_DMC_Integration/MappObjectSynch/lib/* teradata.com.cim.tools.dmc.PersonalizationCheckPM ^
-configFile=D:/CIM10/CIM_DMC_Integration/MappObjectSynch/config/MappObjectSynch.properties -customComponentId=OPM100000022

echo import end

echo script end

pause


