import org.apache.commons.lang.StringUtils;
import groovy.sql.Sql;

   trmLogger.info("Communication: " + trmComponent.id + " submitted for approval by " + trmCurrentUser.userName);

   // **********************************************
   // check for approval request. Must be set to 'Y'
   // **********************************************
  
   def wfMsgRow1 = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT Approval_Cd, Approval_Req_User FROM TRM_META_DB.EX_COMMUNICATION WHERE Communication_Id = '" + trmComponent.id + "' AND Approval_Req = 'Y'");         

   if (wfMsgRow1[0] != null) {
      trmLogger.info("InfoBar message: The Approval Request option for Communication: " + trmComponent.id + " had been set to Y");
   }
   else {
      trmLogger.error("The Approval Request option for Communication: " + trmComponent.id + " had not been set. No Approval Request was sent");
      trmInfoBar.addErrorMessage("The Approval Request option for Communication: " + trmComponent.id + " had not been set. No Approval Request was sent");
   }
 
   // ************************
   // check for approver group
   // *************************
   
   def wfMsgRow2 = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT  Approval_Cd, Approval_Req_User FROM TRM_META_DB.EX_COMMUNICATION WHERE Communication_Id = '" + trmComponent.id + "' AND Approval_Req = 'Y' AND Approver_Group_Id IS NOT NULL");         

   if (wfMsgRow2[0] != null) {
      trmLogger.info("InfoBar message: The Approver Group for Communication: " + trmComponent.id + " was found");
   }
   else {
      trmLogger.error("The Approver Group for Communication: " + trmComponent.id + " was not found. No Approval Request was sent");
      trmInfoBar.addErrorMessage("The Approver Group for Communication: " + trmComponent.id + " was not found. No Approval Request was sent");
   }

   // *******************
   // check for approvers
   // ********************
   
   def wfMsgRow3 = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT  User_Id FROM TRM_META_DB.CR_GROUP_USER WHERE Group_Id IN ( SELECT Approver_Group_Id FROM TRM_META_DB.EX_COMMUNICATION WHERE Communication_Id = '" + trmComponent.id + "' AND Approval_Req = 'Y' AND Approver_Group_Id IS NOT NULL)");         

   if (wfMsgRow3[0] != null) {
      trmLogger.info("InfoBar message: Approvers for Communication: " + trmComponent.id + " found");
   }
   else {
      trmLogger.error("Approvers for Communication: " + trmComponent.id + " were not found. No Approval Request was sent");
      trmInfoBar.addErrorMessage("Approvers for Communication: " + trmComponent.id + " were not found. No Approval Request was sent");
   }

   // ***************************************
   // check for previous submittals/approvals
   // ***************************************
              
   def wfMsgRow4 = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT  Approval_Cd, Approval_Req_User FROM TRM_META_DB.EX_COMMUNICATION WHERE COMMUNICATION_ID = '" + trmComponent.id + "' AND Approval_Req = 'Y' AND Approver_Group_Id IS NOT NULL");         
   def approvalCd = 0;
   def insertRow = true;
   if (wfMsgRow4[0] != null) {
      insertRow = false;
      approvalCd = wfMsgRow4[0].get("Approval_Cd");
      // def approvalReqUserName = wfMsgRow[0].get("Approval_Req_User");

      switch (approvalCd) {
     	   case 1: 
            requestUserInfo = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT  U.User_Id, U.Email, U.First_Name || ' ' || U.Last_Name AS Display_Name FROM TRM_META_DB.CR_USER U INNER JOIN EX_COMMUNICATION EX ON EX.Approval_Req_User = U.User_Name WHERE EX.Communication_Id = '${trmComponent.id}'");
            requestUserInfo = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT  U.Email, U.First_Name || ' ' || U.Last_Name AS Display_Name FROM TRM_META_DB.CR_USER U INNER JOIN EX_COMMUNICATION EX ON EX.Approval_Req_User = U.User_Name WHERE EX.Communication_Id = '${trmComponent.id}'");
        		requestUserName = requestUserInfo[0].get("Display_Name");
            trmLogger.info("InfoBar message: Communication: " + trmComponent.id + " has already been Submitted for Approval by " + requestUserName  + ". No Notification was sent");
            trmInfoBar.addWarningMessage("Communication has already been Submitted for Approval by " + requestUserName  + ". No Notification was sent");
         break;
		
         case 2: 
            trmLogger.info("Communication: " + trmComponent.id + " has already been Approved. No Notification was sent");
            trmInfoBar.addWarningMessage("Communication has already been Approved. No Notification was sent");
         break;
      }
   }

   // **********************************
   // if not previously submitted, do it
   // **********************************
   
   // -- if (approvalCd == 0) {
   if ((approvalCd == 0) || (approvalCd == 3)) {

      // First, check to see if the folder has group security.  If so, use this group

      // -- def folderInfo = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT  Folder_Id FROM TRM_META_DB.CR_FOLDER_ENTRY WHERE Entity_Id = '" + trmComponent.id + "'");
      // -- trmLogger.info("SQL to find Communication's folder: LOCK ROW FOR ACCESS SELECT  Folder_Id FROM TRM_META_DB.CR_FOLDER_ENTRY WHERE Entity_Id = '" + trmComponent.id + "'");
      // -- def folderId = folderInfo[0].get("Folder_Id");
		
      def approverGroupInfo = trmUtilities.executeQuery("LOCK ROW FOR ACCESS SELECT Approver_Group_Id FROM TRM_META_DB.EX_COMMUNICATION WHERE Communication_Id = '" + trmComponent.id + "' AND Approval_Req = 'Y' AND Approver_Group_Id IS NOT NULL");
      trmLogger.info("SQL to find approver group: LOCK ROW FOR ACCESS SELECT Approver_Group_Id FROM TRM_META_DB.EX_COMMUNICATION WHERE Communication_Id = '" + trmComponent.id + "' AND Approval_Req = 'Y' AND Approver_Group_Id IS NOT NULL");
	
      def approverFound = false;
      def approverNames = ""
      def approverGroupId = approverGroupInfo[0].get("Approver_Group_Id"); // there should be only one group

      def dateTime = Calendar.getInstance();
      def currentTimestamp = String.format('%tm-%<td-%<tY %<tT', dateTime);
      def currentDate = String.format('%tY-%<tm-%<td', dateTime);

      // Approval Requestor email address
      def fromEmail = trmCurrentUser.email;
      trmLogger.info("fromEmail: " + fromEmail);
      
      // Communication link embbedded in email
      def emailText = "Communication " + trmComponent.link + " has been submitted by " + trmCurrentUser.displayname + " for your approval.<BR><BR>";
      trmLogger.info("emailtext: " + emailText);
      
      // Email Subject
      def emailSubject = "Communication " + trmComponent.name  + " has been submitted for approval.";
      trmLogger.info("emailSubject: " + emailSubject);
      
      def approverListString = "LOCK ROW FOR ACCESS SELECT DISTINCT First_Name || ' ' || Last_Name as FullName, Email " +
                	             "FROM TRM_META_DB.CR_USER WHERE User_Id IN (SELECT User_Id FROM TRM_META_DB.CR_GROUP_USER " +
				 		                   "WHERE Group_Id = '" + approverGroupId + "')";
			def approverList = trmUtilities.executeQuery(approverListString);
			trmLogger.info("approverList: " + approverList);

      approverList.each() {
      def toEmail = it.Email;
         if (toEmail != null) {
            trmUtilities.sendEmail(fromEmail,toEmail,emailText,emailSubject);
            approverFound = true;
            approverNames = approverNames + it.FullName + ", ";
            trmLogger.info("toEmai: " + toEmail);
            trmLogger.info("approverNames: " + approverNames);
            
         } else {
            trmLogger.info("No valid email for user: " + it.User_Name);
         }
      }   
      if (approverFound) {
         
         if (insertRow) {
            def insertString = "INSERT INTO TRM_META_DB.EX_COMMUNICATION " +
            "(Communication_Id, " +
            " Approval_Cd, " +
            " Approval_Req_User, " + 
            " Approval_Req_Dttm" + 
            " ) VALUES " +
            "('" + trmComponent.id + "', " +
            " 1, " +
            " '" + trmCurrentUser.username + "', " +
            " CURRENT_TIMESTAMP(6)); ";         

            def wfMsgRow5 = trmUtilities.executeQuery(insertString);
            trmLogger.info("SQL to insert record to EX_COMMUNICATION: " + wfMsgRow5);
         } else {
            def updateString = "UPDATE TRM_META_DB.EX_COMMUNICATION SET Approval_Cd = 1, " +
            "Approval_Req_User = '" + trmCurrentUser.username + "', " +
            "Approval_Req_Dttm = CURRENT_TIMESTAMP(6) " + 
            " WHERE COMMUNICATION_ID = '" + trmComponent.id + "'";         
            def wfMsgRow6 = trmUtilities.executeQuery(updateString);
            trmLogger.info("SQL to update record in EX_COMMUNICATION: " + wfMsgRow6);
         }

         trmInfoBar.addInfoMessage("Communication has been Submitted for Approval to " + approverNames + ".");
         trmLogger.info("Communication has been Submitted for Approval to " + approverNames + ".");

      } else {
      
         // if no user, or no email address available, then fail
            
         trmLogger.warning("No valid approvers were found.  No notifications were sent.");
         trmInfoBar.addErrorMessage("No valid approvers were found.  No notifications were sent.");
      }
   }
	