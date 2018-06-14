import org.apache.commons.lang.StringUtils;
import groovy.sql.Sql;


//  check for previous submittals/approvals
              
     	def wfMsgRow = trmUtilities.executeQuery("SELECT Approval_Cd FROM TRM_META_DB.EX_EXTRACT_FORMAT WHERE EXTRACT_FORMAT_ID = '" + trmComponent.id + "'");         
     	
	def insertRow = true;
	def approvalCd = 0;
	if (wfMsgRow[0] != null) {
		insertRow = false;
		approvalCd = wfMsgRow[0].get("Approval_Cd");

		switch (approvalCd) {
     			case 1: 
			     	def approvalReqUserName = wfMsgRow[0].get("Approval_Req_User");
				def requestUserInfo = trmUtilities.executeQuery("SELECT u.EMAIL, u.FIRST_NAME || ' ' || u.LAST_NAME AS DISPLAY_NAME FROM TRM_META_DB.CR_USER u INNER JOIN TRM_META_DB.EX_COMMUNCICATION ex ON ex.approval_Req_User = u.USER_NAME WHERE ex.EXTRACT_FORMAT_ID = '${trmComponent.id}'");
        			def requestUserName = requestUserInfo[0].get("FIRST_NAME") + " " + requestUserInfo[0].get("LAST_NAME");
     				trmInfoBar.addWarningMessage("Extract Format was submitted for Approval by " + approvalReqUser + ". No Notification was sent");
				break;
			
			case 2: 
     				trmInfoBar.addWarningMessage("Extract Format has been previously Approved. No Notification was sent");
				break;
		
		}
	}


// if submitted, send approval
	if ((approvalCd == 0) || (approvalCd == 3)) {

	  	trmComponent.attributes.setValue('Approval Status', 2) ;

		if (insertRow) {
	     		def wfMsgRow2 = trmUtilities.executeQuery("INSERT INTO TRM_META_DB.EX_EXTRACT_FORMAT " +
					"(EXTRACT_FORMAT_Id, " +
					" Approval_Cd, " +
					" Approval_Req_User, " + 
					" Approval_Req_Dttm, " + 
					" Approver_User, " +
					" Approval_Dttm" + 
					" ) VALUES " +
					"('" + trmComponent.id + "', " +
					" 2, " +
					" '" + trmCurrentUser.username + "', " +
					" CURRENT_TIMESTAMP(6), " + 
					" '" + trmCurrentUser.username + "', " +
					" CURRENT_TIMESTAMP(6)); ");         
		} else {
	     		def wfMsgRow3 = trmUtilities.executeQuery("UPDATE TRM_META_DB.EX_EXTRACT_FORMAT SET Approval_Cd = 2, " +
					"Approval_Req_User = '" + trmCurrentUser.username + "', " +
					"Approval_Req_Dttm = CURRENT_TIMESTAMP(6), " + 
					"Approver_User = '" + trmCurrentUser.username + "', " +
					"Approval_Dttm = CURRENT_TIMESTAMP(6) " + 
					" WHERE EXTRACT_FORMAT_ID = '" + trmComponent.id + "'");         
		}

  	  	def dateTime = Calendar.getInstance();
  	  	def currentTimestamp = String.format('%tm-%<td-%<tY %<tT', dateTime);
  	  	def currentDate = String.format('%tY-%<tm-%<td', dateTime);

  	  	def fromEmail = trmCurrentUser.email;
  	  	def toEmail = trmCurrentUser.email;
  	  	def text = "Extract Format: " + trmComponent.link + " has been approved for self use.<BR><BR>";
  	  	def subject = trmComponent.componentType + " " + trmComponent.name  + " has been approved for self use.";
//	            +  currentTimestamp + " " + trmCurrentUser.displayname + ".\n\n";


	  	trmUtilities.sendEmail(fromEmail,toEmail,text,subject);


	  	trmInfoBar.addInfoMessage("Extract Format self approval has been completed. You will receive a notification email shortly.");

	}