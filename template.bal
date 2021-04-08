import ballerina/http;
import ballerina/io;
import ballerinax/sfdc;
import ballerina/time;

// Salesforce client configuration
configurable http:OAuth2DirectTokenConfig & readonly sfdcOauthConfig = ?;
configurable string & readonly sfdc_baseUrl = ?;
configurable string & readonly campaignId = ?;

configurable string & readonly accountId = ?;
configurable string & readonly accountIndustry = ?;
configurable string & readonly billingLatitude = ?;
configurable string & readonly billingLongitude = ?;

configurable int & readonly port = ?;
configurable string & readonly filePath = ?;

boolean isFirstRun = true;
io:WritableCSVChannel wCsvChannel = check io:openWritableCsvFile(filePath);

// Initialize Salesforce client 
sfdc:SalesforceConfiguration sfClientConfiguration = {
    baseUrl: sfdc_baseUrl,
    clientConfig: sfdcOauthConfig
};

// Create Salesforce client.
sfdc:BaseClient baseClient = checkpanic new (sfClientConfiguration);

service / on new http:Listener(8080) {
    resource function get emails(http:Caller caller) returns error? {
        string query = "";
        time:Time durationStart = time:currentTime();
        durationStart = check time:subtractDuration(durationStart, {days: 1});
        string time = check time:format(durationStart, "yyyy-MM-dd'T'HH:mm:ssZ");

        if (isFirstRun) {
            query = string `SELECT Email FROM Contact WHERE Id IN (SELECT contactId FROM CampaignMember WHERE 
                campaignId = '${campaignId}' AND contactId != null) AND Email != null AND CreatedDate < ${time}`;
            isFirstRun = false;
        } else {
            //query = string `SELECT Contact.Email FROM CampaignMember WHERE campaignId = '${campaignId}' AND 
            //  Contact.Email != null AND Contact.Account.Industry = '${accountIndustry}'`; 
            //query = string `SELECT Contact.Email FROM CampaignMember WHERE campaignId = '${campaignId}' AND 
            //  Contact.Email != null AND Contact.Account.Id = '${accountId}'`; 
            //query = string `SELECT Contact.Email FROM CampaignMember WHERE campaignId = '${campaignId}' AND 
            //  Contact.Email != null AND Contact.Account.BillingLatitude = ${billingLatitude} AND 
            //  Contact.Account.BillingLongitude = '${billingLongitude}'`; 

            query = string `SELECT Email FROM Contact WHERE Id IN (SELECT contactId FROM CampaignMember WHERE 
                campaignId = '${campaignId}' AND contactId != null) AND Email != null AND CreatedDate > ${time}`;     
        }
        sfdc:SoqlResult|sfdc:Error result = baseClient->getQueryResult(query);
        if (result is sfdc:SoqlResult) {
            json[] records = result.records;
            foreach var item in records {
                string emailAddress = check item.Email;
                check wCsvChannel.write([emailAddress]); 
            }           
            _ = check caller->respond(http:STATUS_CREATED);
        } else {
            _ = check caller->respond(http:FAILED);
        }
    }
}
