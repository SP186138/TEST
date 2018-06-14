rem Files concatenate
FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
   move /y "%%i" "\\VA1UCPZLAP1CP04.va1.savvis.net\Icrm\outbound\CAMPGNRUS"
)