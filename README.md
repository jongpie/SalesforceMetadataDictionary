# Metadata Dictionary for Salesforce
[![Travis CI](https://img.shields.io/travis/jongpie/SalesforceMetadataDictionary/master.svg)](https://travis-ci.org/jongpie/SalesforceMetadataDictionary)

<a href="https://githubsfdeploy.herokuapp.com" target="_blank">
    <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

Designed for Salesforce admins & developers. Plan, manage and document metadata changes for your Salesforce org.

## Using the App
1. Install in your Salesforce org
2. Run this Apex script to schedule automatic analysis, automatic backup (to static resources) and a one-time analysis
    ```
    // One-time analysis to get immediate results
    Database.executebatch(new MetadataSObjectAnalyzer());
    
    // Scan for metadata changes every 5 minutes
    MetadataSObjectAnalysisScheduler.scheduleEveryXMinutes(5);
    
    // Backup the app's data to static resources every hour
    MetadataSObjectAnalysisBackupScheduler.scheduleHourly(0);

    ```
3. In Lightning Experience, switch to the app 'Metadata Dictionary'
