# java-thread-monitor-and-dumper
Bash script that will check a Java Linux process and as soon as too many threads are created starts thread dumping

## How to use the script

Execute the script to get the help menu
```
./process-monitor-for-java-threads.sh, 2015-01-22-RBR
Usage: 
    nohup ./process-monitor-for-java-threads.sh -procuniqueid <your-proc-id> [-checkinterval <checkminutes>] [-loopduration <loopminutes>] [-threaddumpdir <dir>] [-threaddumpmaxbackup <#>] [-ulimitmaxprocThreadDumpStart <#>] &
    Do not run with ROOT user !
    -procuniqueid . The string that is contained in your process, used to grep the ps command. No quotes allowed
    -checkinterval in minutes. Default = 1. Process will be checked every x minutes.
    -loopduration in minutes. Default = 60. Help : 60 = 1 hour, 1440 = 1 day ,10080 = 1 week, 43829 ~ 1 month
    -threaddumpdir . Default = /data/redhat/redhat_projects/201x_xx_smabtp/2015_01_22_smabtp/java-thread-monitor-and-dumper. All logs and threaddumps will be placed here.
    -threaddumpmaxbackup the maximum threaddumps created. Default = 100. Avoid disk full issue.
    -ulimitmaxprocThreadDumpStart . Limit where script starts to create thread dumps. Default = 800
Behavior:
    This script will run for <loopminutes> minutes and will monitor the number of processes created by the process
    The procuniqueid does not have to exist at the moment of exection
Output: 
    <dir>/./process-monitor-for-java-threads.sh.log
    <dir>/theaddump1-2015-01-22-10-45-27.log
Example: 
    nohup ./process-monitor-for-java-threads.sh -procuniqueid 'app.name=rhq-server' -checkinterval 1 -loopduration 10080 &
    nohup ./process-monitor-for-java-threads.sh -procuniqueid 'app.name=rhq-server' -checkinterval 1 -loopduration 10080 -threaddumpdir /tmp/process-monitor-for-java-threads.sh -threaddumpmaxbackup 50 -ulimitmaxprocThreadDumpStart 800 &
```

## Default values
You can test the script by simply typing 3 words :
```
./process-monitor-for-java-threads.sh -procuniqueid 'app.name=rhq-server' 
```
The last word 'app.name=rhq-server' needs to be a unique part of your Linux Java process that you want to monitor.


## How to read the logs
A CSV file is being created, which can be analysed using an Spreadsheet
'string'= the unique string that identifies the process

'# pids = should be 1, otherwise the 'string' identifier is not chosen correctly and returns multiple results
pid     = the PID of the process
'# threads = the number of threads that vary from check to check

```
timestamp,'string',# pids,pid,# threads
2015-01-22-15-54-16,'freemind.main.FreeMindStarter',1,23273,31
2015-01-22-15-55-16,'freemind.main.FreeMindStarter',1,23273,33
2015-01-22-15-56-16,'freemind.main.FreeMindStarter',1,23273,38
2015-01-22-15-57-16,'freemind.main.FreeMindStarter',1,23273,41
2015-01-22-15-58-16,'freemind.main.FreeMindStarter',1,23273,34
```