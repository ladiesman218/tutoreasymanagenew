
In order to control if a language is shown, and to set a total price for all its courses(optional), language itself is stored in database

Use this command to transfer files to remote servers:
`rsync -iavhe "ssh -i ~/.ssh/tutoreasymanage_key.pem" /Users/leigao/myProjects/TutorEasyManage/ azureuser@20.243.114.35:/home/azureuser/TutorEasyManage/ --delete`
-i: output a change-summary for all updates
-a: archive mode, equals to -rlptgoD
-v: verbose mode
-h: human readable numbers
-e:  allows you to choose an alternative remote shell program to use for communication between the local and remote copies of rsync. This enables the "ssh -i ~/.ssh/tutoreasymanage_key.pem" part which allows us to ues ssh key.
--delete: delete removed files in destination folder. This only works when both source and target/destination are both deirectories, means they have trailing slashes. 
Use -n to dry run first, see what will be deleted/updated. Without deletion, renamed old files will stay there and may cause compile errors.
