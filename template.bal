import ballerina/http;
import ballerina/log;
import ballerinax/sfdc;
import ballerina/task;
import ballerina/time;
import lakshans/azure_storage_service.blobs as azure_blobs;
import ballerina/io;

// Salesforce client configuration
configurable http:OAuth2DirectTokenConfig & readonly sfdcOauthConfig = ?;
configurable string & readonly sfdc_baseUrl = ?;

// Azure Blob Configuration
configurable string & readonly accessKeyOrSAS  = ?;
configurable string & readonly accountName = ?; 
configurable string & readonly containerName = ?;

// Variables for differentiating the results
configurable string & readonly salesforceAccountName = ?;
configurable string & readonly accountIndustry = ?;
configurable string & readonly billingCity = ?;

configurable int & readonly intervalInMillis = ?;
configurable string & readonly authorizationMethod = ?;
boolean isFirstRun = true;

// Initialize Salesforce client 
sfdc:SalesforceConfiguration sfClientConfiguration = {
    baseUrl: sfdc_baseUrl,
    clientConfig: sfdcOauthConfig
};
sfdc:BaseClient baseClient = checkpanic new (sfClientConfiguration);

// Azure Blob Client Initialization
azure_blobs:AzureBlobServiceConfiguration blobServiceConfig = {
    accessKeyOrSAS: accessKeyOrSAS,
    accountName: accountName,
    authorizationMethod: check getAuthMethod(authorizationMethod)
};
azure_blobs:BlobClient blobClient = check new (blobServiceConfig);

// Schedular configuration
task:TimerConfiguration timerConfiguration = {
    intervalInMillis: 1000,
    initialDelayInMillis: 0
};

listener task:Listener timer = new(timerConfiguration);

// Creating a service on the `timer` task Listener.
service on timer {
    // This resource triggers when the timer goes off.
    remote function onTrigger() returns error? {
        string query = "";
        string[][] emailList = [];
        time:Time durationStart = time:currentTime();
        time:Time durationStart2 = check time:subtractDuration(durationStart, {days: 1});
        string time = check time:format(durationStart2, "yyyy-MM-dd'T'HH:mm:ssZ");

        if (isFirstRun) {
            query = string `SELECT Email FROM Contact WHERE AccountId IN (SELECT Id From Account WHERE Name = 
                '${salesforceAccountName}' AND Industry = '${accountIndustry}' AND BillingCity = '${billingCity}') AND  
                CreatedDate < ${time}`;
            isFirstRun = false;
        } else {
            query = string `SELECT Email FROM Contact WHERE AccountId IN (SELECT Id From Account WHERE Name = 
                '${salesforceAccountName}' AND Industry = '${accountIndustry}' AND  BillingCity = '${billingCity}') AND 
                CreatedDate > ${time}`;
        }
        sfdc:SoqlResult|sfdc:Error result = baseClient->getQueryResult(query);
        if (result is sfdc:SoqlResult) {
            json[] records = result.records;
            foreach var item in records {
                string emailAddress = check item.Email;
                emailList.push([emailAddress]);
            } 
            string fileName = string `File-${time:currentTime().time.toString()}.csv`;
            io:println(fileName);
            // if (emailList.length() >= 1) {
            //     var putBlobResult = blobClient->putBlob(containerName, fileName, "BlockBlob", 
            //         emailList.toString().toBytes());
            //     if (putBlobResult is error) {
            //         log:printError(putBlobResult.toString());
            //     } else {
            //         log:print(putBlobResult.toString());
            //         log:print(fileName + " added uploaded successfully");
            //     }
            // }
   
        } else {
            log:printError(msg = result.message());
        }    
    }
}

function getAuthMethod(string authorizationMethod) returns (azure_blobs:SAS|azure_blobs:ACCESS_KEY)|error {
    match authorizationMethod {
        "SAS" => {
            return azure_blobs:SAS;
        }
        "accessKey" => {
            return azure_blobs:ACCESS_KEY;
        }
    }
    return error("Invalid Authorization method");
}
