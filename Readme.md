
For depoly service to remote server, check markdown file named `Deploy with Docker.md`


PDF editing:
1. PDF expert could do editing(verified), Adobe acrobat reader can do editing and link target verification in one place(and easier, without the url encode steps)
2. In Acrobat pro, Select the picture(screen shot of a video), click 编辑文本和图像 icon, then in sub menus select 链接 - 添加/编辑网络链接或文档链接, mouse will become a target aim like shape, select the entire picture zone to create the link.
3. Change link type to hidden rect-angle, link action to open web page. 
4. Paste the relative path of the pdf file itself to the linked file, to the url text box, click ok and save the pdf. 
5. Sample: say if a pdf is at '~/myProjects/Courses/Scratch/编程屋/第02课：小熊过马路/第02课：小熊过马路.pdf', the link target is a video reside at '~/myProjects/Courses/Scratch/编程屋/第02课：小熊过马路/第2课：小熊过马路教学步骤/第1步 课程导入.mp4', the relative path should be '第2课：小熊过马路教学步骤/第1步 课程导入.mp4', put that into the url text box. Close the link edit menu, then click to verify if the link is correct.


When setting up IAP in appstore connect, make sure "VIP" is contained in VIP membership's localizedTitle, and is the only product that contains this string, otherwise this product may appear at lower position on client side.


Course directory structure:
Stages and chapters are identified as folders. 
tobe update



For all API endpoint that should be or can be cached on client side, return encoded response instead of actual data. Before returning the response, create a http header and add etag so that client side has a way to know if the cached response is stale. For value of etag header, use String(describing: object).persistantHash.description. If a property of the object has changed, the String(describing: object) should be different, persistantHash of the description is of type Int, so we use the 2nd description to convert that int to string, which makes it easier for adding to/getting from headers for comparing. This is better than making the class/struct comform to Hashable and use its hashValue, becoz according to documentation, "hashValue is not guaranteed to be equal across different executions of your program". There is also a hash property for string, but that just shows the memory address of the string and doesn't' relfect change on the string's value.
