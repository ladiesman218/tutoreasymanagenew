
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

PDF editing:
1. PDF expert could do editing(verified), Adobe acrobat reader may do editing and verify link target in one place(guess, try taobao hacked version first to verify it.)
2. Find out the RELATIVE path between pdf file and the target resource
3. Copy and paste that relative path to http://www.jsons.cn/urlencode/o or https://www.woodmanzhang.com/webkit/urlencode/index.html or any baidu search result of 'url encode在线编码'
4. Sub paths can be tricky, coz any slash in the path will be encoded into '%2F', that's fine for our purpose, but when the editors try to verify the link themselves, it may not work. So replace %2F back to /, or find a better way to encode url
5. Sample: say if a pdf is at '~/myProjects/Courses/Scratch/编程屋/第02课：小熊过马路/第02课：小熊过马路.pdf', the link target is a video reside at '~/myProjects/Courses/Scratch/编程屋/第02课：小熊过马路/第2课：小熊过马路教学步骤/第1步 课程导入.mp4', the relative path should be '第2课：小熊过马路教学步骤/第1步 课程导入.mp4', copy and encode it, then deal with the slash.


When setting up IAP in appstore connect, make sure "VIP" is contained in VIP membership's localizedTitle, and is the only product that contains this string, otherwise this product may appear at lower position on client side.
