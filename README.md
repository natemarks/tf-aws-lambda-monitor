This module deploys a montor funcotjn that is triggered by a cloudwatch schedule and writes events to  cloudwatch logs

Assumptions:

 - Alarms will be generated analyzing logs. That configuration is not in the scope of this module 
   
 - Tracing is off by deault , but could easily be turned on

 - Debug logging is enabled by  setting the environment variable "DEBUG_FUNCTION" to true

 - The lambda source is pre-packaged into a zip on an s3 bucket that's accessible from the account that runs this module

 - The lambda only requires internet access. if it needs to inteact with AWS services, this module would have to be extended