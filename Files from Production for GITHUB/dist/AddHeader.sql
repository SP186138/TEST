.RUN FILE=..\logon.sql

.SET WIDTH 3000;
.SET TITLEDASHES OFF;
.SET SIDETITLES OFF;

--------------------------------------------------------------------------------------------------
-- Deleting the file that contains the Header Row                                               --
--------------------------------------------------------------------------------------------------
.OS del "Headerrow$TRM_TPLT.tmp"

--------------------------------------------------------------------------------------------------
-- Export the result of the SQL, which is the Header Row, to a flat file                        --
--------------------------------------------------------------------------------------------------
.EXPORT FILE="Headerrow$TRM_TPLT.tmp"

database TRM_META_DB;

WITH RECURSIVE HeaderRow(Description, Display_Ord, Presentation_Template_Id, Field_Delimiter_Txt, Extract_Format_Id) AS
(	SELECT
	  CASE WHEN COALESCE(omee.Description,'') = '' THEN omee.Name ELSE omee.Description END (VARCHAR(3000))
	 ,omee.Display_Ord 
	 ,ompt.Presentation_Template_Id 
	 ,ompt.Field_Delimiter_Txt
	 ,ompt.Extract_Format_Id
	FROM om_presentation_template ompt
	INNER JOIN OM_EXTRACT_Element omee
	     ON omee.Extract_Format_Id = ompt.Extract_Format_Id
	WHERE omee.Display_Ord = 0
	  AND ompt.Output_Destination_Type_Cd = 1 /* File */
	  AND ompt.Output_Mode_Cd = 2 /* Overwrite */
	UNION ALL
	SELECT
	   direct.Description 
	      ||direct.Field_Delimiter_Txt
	      ||CASE WHEN COALESCE(indirect.Description,'') = '' THEN indirect.Name ELSE indirect.Description END (VARCHAR(3000))
	  ,direct.Display_Ord + 1 AS "LEVEL"
	  ,direct.Presentation_Template_Id 
	  ,direct.Field_Delimiter_Txt
	  ,indirect.Extract_Format_Id
	 FROM HeaderRow direct
	        , OM_EXTRACT_Element indirect 
	 WHERE  direct.Extract_Format_Id = indirect.Extract_Format_Id
	      AND indirect.Display_Ord = "LEVEL"
)
SELECT 
 MAX(Description) || Field_Delimiter_Txt  (TITLE '')
FROM HeaderRow
WHERE Presentation_Template_Id = '$TRM_TPLT'
GROUP BY Presentation_Template_Id, Field_Delimiter_Txt
;

.EXPORT RESET;

.LOGOFF;

.QUIT;