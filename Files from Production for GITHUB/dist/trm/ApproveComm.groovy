import org.apache.commons.lang.StringUtils;
import groovy.sql.Sql;


//  check for previous submittals/approvals
              
   def wfMsgRow = trmUtilities.executeQuery("SELECT Approval_Cd, Approval_Req_User, Approval_Req_Dttm, Approver_User, Approval_Dttm FROM TRM_META_DB.EX_COMMUNICATION WHERE Communication_Id = '" + trmComponent.id + "' AND Approval_Req = 'Y' AND Approver_Group_Id IS NOT NULL");
   def approvalCd = 0;
   if (wfMsgRow[0] == null) {
      trmInfoBar.addWarningMessage("Communication was never submitted for Approval. No Notification was sent");
   } else {
      approvalCd = wfMsgRow[0].get("Approval_Cd");
      def approver = wfMsgRow[0].get("Approver_User");
      def approval_Dttm = wfMsgRow[0].get("Approval_Dttm");
      def approverName = "";
      if (((approvalCd == 2) || (approvalCd == 3)) && (approver != null)) {
         def approverInfo = trmUtilities.executeQuery("SELECT First_Name || '' '' || Last_Name AS FullName FROM TRM_META_DB.CR_USER WHERE USER_NAME = '" + approver + "'");         
			   approverName = approverInfo[0].get("FullName")
      }

      switch (approvalCd) {
         case 0: 
            trmInfoBar.addWarningMessage("Communication was never submitted for Approval. No Notification was sent");
         break;
		
         case 2: 
            trmInfoBar.addWarningMessage("Communication has been previously Approved by " + approverName + " on " + approval_Dttm + ". No Notification was sent");
         break;
		
         case 3: 
            trmInfoBar.addWarningMessage("Communication has been previously Rejected by " + approverName + " on " + approval_Dttm + ". No Notification was sent");
         break;
      }

   }
   
// if submitted, send approval
   
   if (approvalCd == 1) {

// trmComponent.attributes.setValue('Approval Status', 2) ;

      def dateTime = Calendar.getInstance();
      def currentTimestamp = String.format('%tm-%<td-%<tY %<tT', dateTime);
      def currentDate = String.format('%tY-%<tm-%<td', dateTime);
      def submitterEmailInfo = trmUtilities.executeQuery("SELECT User_Name, First_Name || ' ' || Last_Name as FullName, Email " +
                                                         "FROM TRM_META_DB.CR_USER WHERE User_Name = '" + wfMsgRow[0].get("Approval_Req_User") + "'");
      def submitterEmail = submitterEmailInfo[0].get("Email");
      def submitterName = submitterEmailInfo[0].get("FullName");
      def wfMsgRow2 = trmUtilities.executeQuery("UPDATE TRM_META_DB.EX_COMMUNICATION SET Approval_Cd = 2, " +
				                                        "Approver_User = '" + trmCurrentUser.username + "', " +
				                                        "Approval_Dttm = CURRENT_TIMESTAMP(6) " + 
				                                        "WHERE Communication_Id = '" + trmComponent.id + "'");         

      if (submitterEmail != null) {
         def fromEmail = trmCurrentUser.email;
         def toEmail = submitterEmail;
         def text = trmComponent.link + " has been approved " + trmCurrentUser.displayname + ".<BR><BR>";
         def subject = "Communication " + trmComponent.name  + " has been approved.";
         //	            +  currentTimestamp + " " + trmCurrentUser.displayname + ".\n\n";

         trmUtilities.sendEmail(fromEmail,toEmail,text,subject);
         trmInfoBar.addInfoMessage("Communication Approval has been sent to " + submitterName + ".");
      } else {
         trmInfoBar.addWarningMessage("Submit User, " + submitterName + " has no valid email address in the TRM system. The approval has processed, but No notification has been sent");
      }
   }