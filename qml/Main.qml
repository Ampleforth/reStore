import QtQuick
import net.asivery.AppLoad 1.0

Rectangle {
    id:root
    anchors.fill:parent;color:"#f4f4f4"
    signal close
    property bool testing:false
    property bool shuttingDown:false
    property string query:""
    property string view:"home"
    property string previousView:"home"
    property string settingsPreviousView:"home"
    property string message:""
    property bool busy:false
    property bool keyboardOpen:false
    property bool folderOpen:false
    property var books:[]
    property var selectedBook:null
    property var links:[]
    property var folders:[]
    property string folderID:""
    property string secretKeyDraft:""
    property bool hasSecretKey:false
    property var account:({signed_in:false,message:"Not signed in"})
    property bool accountVerification:false
    property string downloadMode:"slow"
    property var requests:[]
    property string browserImage:""
    property string browserURL:""
    property string browserText:""
    property bool browserBusy:false
    property bool browserInteracting:false
    property var browserActions:[]
    property string selectedLink:""
    property var downloadStatus:({state:"idle"})
    property bool importing:false
    property bool statusPolling:false
    readonly property bool transferFinished:importing||downloadStatus.state==="complete"||downloadStatus.state==="imported"||downloadStatus.state==="import-error"
    property int page:1
    property bool hasNext:false
    AppLoad {id:endpoint;applicationID:"farm.virus.archive-books"}
    FontLoader {objectName:"bodyFont";source:"fonts/DejaVuSans.ttf"}
    FontLoader {source:"fonts/DejaVuSans-Bold.ttf"}
    FontLoader {source:"fonts/NotoSansSymbols2-Regular.ttf"}
    component NoticeText: AppText {
        font.pixelSize:28;font.weight:Font.Normal;font.bold:false
        horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;lineHeight:1.22
    }
    function responseValue(status,body,path){
        var context=" ("+path+", HTTP "+status+")"
        if(status===0)throw "Cannot connect to the local reStore service. Close and reopen reStore. If this continues, check the installed backend and device architecture."+context
        if(!body||!body.trim())throw "The local reStore service returned an empty response."+context
        var value
        try {value=JSON.parse(body)}
        catch(e){throw "The local reStore service returned an invalid response. Check that the app and backend are from the same release."+context}
        if(!value||typeof value!=="object"||Array.isArray(value))throw "The local reStore service returned an unexpected response."+context
        if(value.error)throw (typeof value.error==="string"?value.error:"The local reStore service reported an error")+context
        if(status!==200)throw "The local reStore service could not complete the request."+context
        return value
    }
    function requestFailure(error){
        message=String(error);busy=false;browserBusy=false
        if(view==="browser")browserActions=[]
        if(importing){importing=false;downloadStatus=Object.assign({},downloadStatus,{state:"import-error"})}
    }
    function request(method,path,data,done,failed) {
        if(testing||shuttingDown)return
        var xhr=new XMLHttpRequest();requests=requests.concat([xhr])
        xhr.onreadystatechange=function(){
            if(shuttingDown||xhr.readyState!==XMLHttpRequest.DONE)return
            requests=requests.filter(function(x){return x!==xhr})
            var v
            try {v=responseValue(xhr.status,xhr.responseText,path)}
            catch(e){if(failed)failed(String(e),xhr.status);else requestFailure(e);return}
            try {done(v)}catch(e){requestFailure(e)}
        }
        xhr.open(method,"http://127.0.0.1:38767"+path)
        xhr.setRequestHeader("X-ArchiveBooks-Request","app")
        if(method!=="GET")xhr.setRequestHeader("Content-Type","application/json")
        xhr.send(data===null?null:JSON.stringify(data))
    }
    function loadSettings(startup,attempt){
        attempt=attempt||0
        if(startup)busy=true
        request("GET","/settings",null,function(v){
            settingsRetry.stop();folderID=v.folder;folders=v.folders;hasSecretKey=!!v.hasSecretKey
            if(startup){busy=false;message="";if(hasSecretKey)loginAccount(true)}
        },function(error,status){
            if(startup&&status===0&&attempt<10&&!shuttingDown){
                message="Starting the local reStore service…";settingsRetry.attempt=attempt+1;settingsRetry.restart()
            }else requestFailure(error)
        })
    }
    function handleAccount(v){
        busy=false;account=v.account||account;message=v.message||account.message||""
        if(v.browser){accountVerification=true;if(view!=="browser")showBrowser();else refreshBrowser()}
        else {accountVerification=false;if(view==="browser")view=previousView;links=[];selectedLink=""}
    }
    function loginAccount(reuse){account={signed_in:false,message:"Signing in"};links=[];selectedLink="";busy=true;message="Signing in…";request("POST","/account",{reuse:!!reuse},function(v){handleAccount(v)})}
    function saveAccount(){
        if(busy||!secretKeyDraft.trim())return
        busy=true;keyboardOpen=false
        request("POST","/settings",{secretKey:secretKeyDraft},function(v){hasSecretKey=v.hasSecretKey;secretKeyDraft="";loginAccount(false)})
    }
    function clearAccount(){
        busy=true;keyboardOpen=false
        request("POST","/settings",{secretKey:""},function(v){hasSecretKey=false;secretKeyDraft="";account={signed_in:false,message:"Signing out"};links=[];selectedLink="";request("POST","/account/logout",{},function(reply){handleAccount(reply)})})
    }
    function folderName(){var f=folders.find(function(f){return f.id===folderID});return f?f.name:"Choose a folder"}
    function search(n){
        if(busy||!query.trim())return
        accountVerification=false;keyboardOpen=false;busy=true;message="Searching…";page=n||1
        request("POST","/search",{query:query,page:page},function(v){busy=false;books=v.books||[];hasNext=!!v.next;view="results";message=v.message||"";if(v.browser)showBrowser()})
    }
    function openBook(book){
        accountVerification=false;selectedBook=book;links=[];selectedLink="";downloadMode=account.signed_in?"fast":"slow";busy=true;message="Loading book…";view="book"
        request("POST","/book",{url:book.url},function(v){busy=false;var merged=Object.assign({},book);Object.keys(v.book||{}).forEach(function(key){if(v.book[key])merged[key]=v.book[key]});selectedBook=merged;downloadMode=v.mode||downloadMode;links=v.links||[];selectedLink=links.length?links[0].url:"";message=v.message||"";if(v.browser)showBrowser()})
    }
    function showBrowser(){previousView=view;browserActions=[];view="browser";keyboardOpen=false;refreshBrowser()}
    function refreshBrowser(){
        if(browserBusy)return
        browserBusy=true;request("GET","/browser",null,function(v){handleBrowserFrame(v)})
    }
    function handleBrowserFrame(v){
        browserBusy=false;browserImage=v.image;browserURL=v.url;message=v.message||""
        if(v.editableFocused){browserText="";keyboardOpen=true}
        if(v.verificationReady&&view==="browser"&&!keyboardOpen&&!browserInteracting&&!browserActions.length&&!busy){resume();return}
        pumpBrowserActions()
    }
    function browserAction(data){browserActions=browserActions.concat([data]);pumpBrowserActions()}
    function pumpBrowserActions(){
        if(browserBusy||!browserActions.length||view!=="browser")return
        var data=browserActions[0];browserActions=browserActions.slice(1);browserBusy=true
        request("POST","/browser",data,function(v){handleBrowserFrame(v)})
    }
    function resume(){
        keyboardOpen=false
        view=previousView
        if(accountVerification){busy=true;request("POST","/account/resume",{},function(v){handleAccount(v)})}
        else if(view==="results")search(page)
        else if(view==="book")openBook(selectedBook)
        else if(view==="download")checkDownload()
    }
    function chooseLink(anchor){picker.show(anchor,downloadMode==="fast"?"Fast download server":"Slow download server",links.map(function(l){return {value:l.url,label:l.label}}),selectedLink,function(value){selectedLink=value})}
    function linkLabel(){var l=links.find(function(l){return l.url===selectedLink});return l?l.label:"Choose a "+downloadMode+" download link"}
    function startDownload(){
        if(!selectedLink||busy)return
        busy=true;view="download";downloadStatus={state:"loading"};message="Connecting to download server…"
        request("POST","/start",{url:selectedLink},function(v){busy=false;applyDownload(v)})
    }
    function applyDownload(v){
        downloadStatus=v;message=v.message||""
        if(v.state==="challenge"){if(view!=="browser")showBrowser()}
        else if(v.state==="complete"&&!importing)importBook()
    }
    function checkDownload(){
        if(busy||importing||statusPolling)return
        statusPolling=true
        request("GET","/status",null,function(v){statusPolling=false;applyDownload(v)},function(error){statusPolling=false;requestFailure(error)})
    }
    function downloadLabel(){
        if(importing)return "Importing into "+folderPicker.path(folderID)+"…"
        var state=downloadStatus.state
        if(state==="waiting")return downloadStatus.seconds===null?"Waiting…":Math.floor(downloadStatus.seconds/60)+":"+String(downloadStatus.seconds%60).padStart(2,"0")
        if(state==="imported")return "Added to "+folderPicker.path(folderID)
        if(state==="complete")return "Preparing import…"
        if(state==="downloading")return downloadStatus.total>0&&downloadStatus.bytes>=downloadStatus.total?"Finishing download…":"Downloading…"
        if(state==="connecting"||state==="loading")return "Connecting…"
        if(state==="import-error")return "Import needs attention"
        if(state==="error")return "Download interrupted"
        if(state==="challenge")return "Verification required"
        if(state==="unknown")return "Download needs attention"
        return "Please wait…"
    }
    function importBook(){
        importing=true;message="Importing into "+folderPicker.path(folderID)+"…"
        request("POST","/download",{title:selectedBook?selectedBook.title:"Book"},function(v){
            if(!nativeImport.item){importing=false;downloadStatus=Object.assign({},downloadStatus,{state:"import-error"});message="The native reMarkable importer is unavailable. Download retained.";return}
            nativeImport.item.begin(v.file,v.folder,selectedBook?selectedBook.title:"")
        })
    }
    function unloading(){if(shuttingDown)return;shuttingDown=true;settingsRetry.stop();poll.stop();downloadPoll.stop();requests.forEach(function(x){x.onreadystatechange=null;x.abort()});requests=[];endpoint.terminate()}
    Component.onCompleted:if(!testing)loadSettings(true)
    Timer {id:settingsRetry;interval:500;property int attempt:0;onTriggered:root.loadSettings(true,attempt)}
    Timer {id:poll;interval:3000;repeat:true;running:root.view==="browser"&&!root.testing&&!root.keyboardOpen&&!root.browserInteracting&&!root.browserActions.length;onTriggered:root.refreshBrowser()}
    Timer {id:downloadPoll;interval:1000;repeat:true;running:root.view==="download"&&!root.testing&&root.downloadStatus.state!=="imported"&&root.downloadStatus.state!=="import-error"&&root.downloadStatus.state!=="error";onTriggered:root.checkDownload()}
    Loader {id:nativeImport;active:!root.testing;source:"NativeImport.qml"}
    Connections {
        target:nativeImport.item
        function onCompleted(){root.importing=false;root.downloadStatus=Object.assign({},root.downloadStatus,{state:"imported"});root.message="Added to "+root.folderName();root.request("POST","/imported",{},function(){})}
        function onFailed(message){root.importing=false;root.downloadStatus=Object.assign({},root.downloadStatus,{state:"import-error"});root.message=message}
    }
    Column {
        anchors.fill:parent;anchors.margins:28;spacing:20
        Item {
            width:parent.width;height:64
            Image {width:64;height:64;source:"books.svg";fillMode:Image.PreserveAspectFit}
            AppText {x:82;anchors.verticalCenter:parent.verticalCenter;text:"reStore";font.pixelSize:32;font.bold:true}
            Row {anchors.right:parent.right;spacing:12
                ToolbarButton {objectName:"settingsButton";icon:"settings";enabled:!root.busy&&!root.importing;onTriggered:{root.keyboardOpen=false;if(root.view!=="settings")root.settingsPreviousView=root.view;root.view="settings";root.loadSettings()}}
                ToolbarButton {icon:"close";onTriggered:root.close()}
            }
        }
        Row {
            width:parent.width;spacing:12;visible:root.view==="home"||root.view==="results"||root.view==="book"
            Rectangle {
                width:parent.width-142;height:68;radius:12;color:"white";border.color:"black";border.width:2
                AppText {x:18;anchors.verticalCenter:parent.verticalCenter;width:parent.width-36;text:root.query||"Search by title, author, or ISBN";color:root.query?"black":"#666666";font.pixelSize:24;elide:Text.ElideRight;textFormat:Text.PlainText}
                MouseArea {objectName:"searchField";anchors.fill:parent;onClicked:root.keyboardOpen=true}
            }
            Action {objectName:"searchButton";width:130;height:68;label:"Search";selected:true;enabled:!root.busy&&!!root.query.trim();onTriggered:root.search(1)}
        }
        AppText {visible:root.view!=="home"&&root.view!=="settings"&&root.view!=="browser";text:"EPUB & PDF";font.pixelSize:18;font.bold:true;color:"black"}
        AppText {width:parent.width;visible:root.message!=="";text:root.message;wrapMode:Text.Wrap;font.pixelSize:21;textFormat:Text.PlainText}
        Item {
            id:body;width:parent.width;height:parent.height-y
            Flickable {
                objectName:"homeNotices";anchors.fill:parent;clip:true;visible:root.view==="home"
                contentHeight:homeNoticesContent.y+homeNoticesContent.height+32
                Column {
                    id:homeNoticesContent;x:Math.min(100,parent.width*0.07);y:56;width:parent.width-2*x;spacing:26
                    NoticeText {width:parent.width;text:"Support the authors.";font.pixelSize:50;font.bold:true;lineHeight:1.1}
                    NoticeText {objectName:"authorSupportText";width:parent.width;text:"Authors deserve to be compensated for their work. If you enjoy a book, please consider purchasing a physical copy or supporting the author in another way."}
                    NoticeText {objectName:"librarySupportText";width:parent.width;text:"If you can’t afford a book, ask your local library if it can purchase a copy for the library.";font.pixelSize:26}
                    Item {width:1;height:12}
                    Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:130;height:4;color:"black"}
                    Item {width:1;height:12}
                    NoticeText {width:parent.width;text:"Keep the library open.";font.pixelSize:46;font.bold:true}
                    NoticeText {objectName:"donationText";width:parent.width;text:"Please consider donating to Anna’s Archive to help preserve books and keep the world’s knowledge accessible to everyone."}
                    Rectangle {
                        width:parent.width;height:membershipNotice.height+52;color:"white";border.width:2;border.color:"black";radius:12
                        Column {id:membershipNotice;x:26;y:26;width:parent.width-52;spacing:20
                            NoticeText {width:parent.width;text:"Your membership works in reStore";font.pixelSize:30;font.bold:true}
                            Rectangle {width:parent.width;height:1;color:"black"}
                            NoticeText {objectName:"membershipBenefitsText";width:parent.width;text:"Membership donations provide fast downloads without a waitlist, with daily download limits based on your membership tier.";font.pixelSize:26}
                            NoticeText {objectName:"membershipSetupText";width:parent.width;text:"Enter your account’s secret key in Settings to sign in and use fast downloads directly in reStore.";font.pixelSize:25}
                        }
                    }
                    NoticeText {objectName:"membershipCaveatText";width:parent.width;text:"Some membership tiers offer fewer browser checks. CAPTCHA verification may still be required in reStore.";font.pixelSize:21;font.italic:true;color:"#444444"}
                }
            }
            Column {
                anchors.fill:parent;spacing:16;visible:root.view==="results"
                Row {spacing:14
                    AppText {text:"Search results · Page "+root.page;font.pixelSize:25;font.bold:true}
                    Action {label:"Previous";width:160;enabled:root.page>1&&!root.busy;onTriggered:root.search(root.page-1)}
                    Action {label:"Next";enabled:root.hasNext&&!root.busy;onTriggered:root.search(root.page+1)}
                }
                ListView {width:parent.width;height:parent.height-y;clip:true;spacing:16;model:root.books
                    delegate:BookCard {required property var modelData;width:ListView.view.width;book:modelData;onOpened:root.openBook(modelData)}
                    AppText {anchors.centerIn:parent;visible:root.books.length===0&&!root.busy;text:"No EPUB or PDF results";font.pixelSize:25}
                }
            }
            Flickable {
                anchors.fill:parent;clip:true;contentHeight:bookContent.height;visible:root.view==="book"
                Column {id:bookContent;width:parent.width;spacing:20
                    Action {label:"Results";icon:"previous";width:160;onTriggered:root.view="results"}
                    BookCard {width:parent.width;book:root.selectedBook||{}}
                    AppText {width:parent.width;text:root.selectedBook?(root.selectedBook.description||""):"";wrapMode:Text.Wrap;font.pixelSize:22;textFormat:Text.PlainText}
                    AppText {text:root.downloadMode==="fast"?"Fast downloads":"Slow downloads";font.pixelSize:28;font.bold:true}
                    Action {id:linkDropdown;objectName:"linkDropdown";width:bookContent.width;height:76;label:root.linkLabel();dropdown:true;enabled:root.links.length>0&&!root.busy;onTriggered:root.chooseLink(linkDropdown)}
                    Action {objectName:"downloadButton";width:220;height:72;label:"Download";selected:true;enabled:!!root.selectedLink&&!root.busy;onTriggered:root.startDownload()}
                    AppText {visible:root.links.length===0&&!root.busy;text:"No "+root.downloadMode+" download links found.";font.pixelSize:22}
                }
            }
            Column {
                anchors.fill:parent;spacing:26;visible:root.view==="download"
                BookCard {width:parent.width;book:root.selectedBook||{title:"Download"}}
                AppText {text:root.linkLabel();font.pixelSize:23}
                Rectangle {
                    width:parent.width;height:Math.max(220,downloadStatusContent.height+48);radius:16;color:"white";border.color:"black";border.width:2
                    Column {id:downloadStatusContent;anchors.centerIn:parent;width:parent.width-40;spacing:18
                        AppText {anchors.horizontalCenter:parent.horizontalCenter;text:root.importing?"Download complete":root.downloadStatus.state==="waiting"?"Download starts in":"Download status";font.pixelSize:24}
                        AppText {objectName:"countdown";width:parent.width;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;font.pixelSize:root.downloadStatus.state==="waiting"?52:root.importing?32:38;font.bold:true;text:root.downloadLabel()}
                        Rectangle {
                            objectName:"downloadProgress";anchors.horizontalCenter:parent.horizontalCenter
                            width:parent.width-60;height:32;color:"white";border.color:"black";border.width:2
                            visible:root.transferFinished||root.downloadStatus.state==="downloading"||root.downloadStatus.state==="connecting"
                            clip:true
                            Rectangle {objectName:"downloadProgressFill";x:2;y:2;height:parent.height-4;color:"black";visible:root.transferFinished||root.downloadStatus.total>0
                                width:root.transferFinished?parent.width-4:visible?(parent.width-4)*Math.min(1,(root.downloadStatus.bytes||0)/root.downloadStatus.total):0
                            }
                            Rectangle {y:2;height:parent.height-4;color:"black";visible:!root.transferFinished&&!(root.downloadStatus.total>0);width:(parent.width-4)/5
                                SequentialAnimation on x {running:downloadProgressTrack.visible&&!root.transferFinished&&!(root.downloadStatus.total>0);loops:Animation.Infinite;NumberAnimation {from:2;to:downloadProgressTrack.width;duration:1400}}
                            }
                            id:downloadProgressTrack
                        }
                        AppText {anchors.horizontalCenter:parent.horizontalCenter;font.pixelSize:21;visible:root.transferFinished||root.downloadStatus.total>0;text:root.transferFinished?"100%":Math.min(100,Math.floor(100*(root.downloadStatus.bytes||0)/root.downloadStatus.total))+"%"}
                        AppText {anchors.horizontalCenter:parent.horizontalCenter;visible:!!root.downloadStatus.bytes;text:(root.downloadStatus.bytes/1048576).toFixed(1)+(root.downloadStatus.total>0?" / "+(root.downloadStatus.total/1048576).toFixed(1):"")+" MB received";font.pixelSize:21}
                    }
                }
                Action {width:270;label:"Show verification";visible:root.downloadStatus.state==="unknown";onTriggered:root.showBrowser()}
                Action {label:"Retry import";width:220;visible:root.downloadStatus.state==="import-error";onTriggered:root.importBook()}
                Action {objectName:"bookDetailsButton";width:230;label:"Book details";icon:"previous";enabled:!root.busy&&!root.importing;onTriggered:root.view="book"}
            }
            Column {
                anchors.fill:parent;spacing:25;visible:root.view==="settings"
                Action {label:"Back";icon:"previous";onTriggered:{root.keyboardOpen=false;root.view=root.settingsPreviousView}}
                AppText {text:"Settings";font.pixelSize:34;font.bold:true}
                AppText {text:"Download books to";font.pixelSize:24}
                Action {objectName:"folderButton";width:parent.width;height:76;label:folderPicker.path(root.folderID);dropdown:true;onTriggered:{root.loadSettings();folderPicker.current=root.folderID;root.folderOpen=true}}
                AppText {width:parent.width;text:"Choose a folder from My files. Downloaded books appear in your reMarkable library.";font.pixelSize:22;wrapMode:Text.Wrap;color:"black"}
                AppText {text:"Anna's Archive account";font.pixelSize:28;font.bold:true}
                AppText {objectName:"accountStatus";width:parent.width;text:root.account.message;wrapMode:Text.Wrap;font.pixelSize:22;textFormat:Text.PlainText}
                Action {objectName:"secretKeyField";width:parent.width;height:76;label:root.secretKeyDraft?"************************":root.hasSecretKey?"Secret key saved (tap to replace)":"Enter secret key";enabled:!root.busy;onTriggered:root.keyboardOpen=true}
                Row {spacing:12
                    Action {objectName:"saveAccountButton";width:240;label:"Save and log in";enabled:!root.busy&&!!root.secretKeyDraft.trim();onTriggered:root.saveAccount()}
                    Action {objectName:"retryAccountButton";width:180;label:"Retry login";enabled:!root.busy&&root.hasSecretKey;onTriggered:root.loginAccount(false)}
                    Action {objectName:"clearAccountButton";width:220;label:"Remove key";enabled:!root.busy&&root.hasSecretKey;onTriggered:root.clearAccount()}
                }
                AppText {width:parent.width;text:"The key is saved privately on this tablet and used when reStore opens. Signed-in accounts show fast download links; an active membership and available quota are required to use them. CAPTCHA checks may still appear.";font.pixelSize:22;wrapMode:Text.Wrap}
            }
            Column {
                anchors.fill:parent;spacing:12;visible:root.view==="browser"
                Row {spacing:10
                    Action {label:"Back";icon:"previous";onTriggered:{root.view=root.previousView;root.keyboardOpen=false}}
                    Action {objectName:"continueButton";label:"Continue";selected:true;width:170;enabled:!root.busy&&!root.browserBusy&&!root.browserActions.length;onTriggered:root.resume()}
                    Action {label:"Refresh";width:150;onTriggered:root.refreshBrowser()}
                }
                AppText {width:parent.width;text:root.browserURL;font.pixelSize:17;elide:Text.ElideMiddle;textFormat:Text.PlainText}
                Rectangle {
                    width:parent.width;height:captchaInstructions.height+28;radius:10;color:"white";border.color:"black";border.width:2
                    Column {id:captchaInstructions;x:14;y:14;width:parent.width-28;spacing:10
                        AppText {objectName:"captchaHelp";width:parent.width;text:"Complete the CAPTCHA. reStore continues automatically when the site accepts it. Use Continue at the top if needed.";font.pixelSize:24;font.bold:true;wrapMode:Text.Wrap}
                        AppText {width:parent.width;text:"Swipe up or down to scroll. Hold before dragging a CAPTCHA puzzle.";font.pixelSize:20;wrapMode:Text.Wrap}
                    }
                }
                Rectangle {
                    id:browserWindow;objectName:"browserWindow";color:"white";border.color:"black";border.width:2;clip:true
                    property real expandedHeight:Math.max(160,parent.height-y-76)
                    width:parent.width
                    height:root.keyboardOpen?Math.min(expandedHeight/2,Math.max(80,keyboard.y-mapToItem(root,0,0).y-browserKeyboardRow.height-24)):expandedHeight
                    Image {id:browserFrame;objectName:"browserFrameImage";anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:8;height:browserWindow.expandedHeight-16;source:root.browserImage;fillMode:Image.PreserveAspectFit;cache:false;asynchronous:true;retainWhileLoading:true}
                    MouseArea {
                        objectName:"browserGesture"
                        anchors.centerIn:browserFrame;width:browserFrame.paintedWidth;height:browserFrame.paintedHeight
                        property real startX:0
                        property real startY:0
                        property bool puzzleDrag:false
                        onPressed:function(mouse){startX=mouse.x;startY=mouse.y;puzzleDrag=false;root.browserInteracting=true}
                        onPressAndHold:puzzleDrag=true
                        onCanceled:root.browserInteracting=false
                        onReleased:function(mouse){
                            root.browserInteracting=false
                            if(width<=0||height<=0)return
                            var dx=mouse.x-startX,dy=mouse.y-startY
                            if(!puzzleDrag&&Math.abs(dy)>36&&Math.abs(dy)>Math.abs(dx)*1.3){root.browserAction({action:"scroll",dy:Math.round(-dy*browserFrame.sourceSize.height/height)});return}
                            var data={action:Math.abs(mouse.x-startX)+Math.abs(mouse.y-startY)>8?"drag":"click",x:startX/width,y:startY/height,endX:Math.max(0,Math.min(1,mouse.x/width)),endY:Math.max(0,Math.min(1,mouse.y/height))}
                            root.browserAction(data)
                        }
                        onWheel:function(wheel){root.browserAction({action:"scroll",dy:-wheel.angleDelta.y});wheel.accepted=true}
                    }
                }
                Row {id:browserKeyboardRow;spacing:10
                    Action {label:"Keyboard";width:160;onTriggered:{root.browserText="";root.keyboardOpen=true}}
                }
            }
        }
    }
    FolderPicker {
        id:folderPicker;anchors.fill:parent;visible:root.folderOpen;folders:root.folders;current:root.folderID
        onCancelled:root.folderOpen=false
        onChosen:function(id){root.request("POST","/settings",{folder:id},function(v){root.folderID=v.folder;root.folders=v.folders;root.folderOpen=false;root.message="Download folder saved"})}
    }
    TouchKeyboard {
        id:keyboard;objectName:"touchKeyboard"
        anchors.bottom:parent.bottom;visible:root.keyboardOpen;secret:false;label:root.view==="settings"?"Account secret key":root.view==="browser"?"Type into the selected page field":"Search books";value:root.view==="settings"?root.secretKeyDraft:root.view==="browser"?root.browserText:root.query
        onEdited:function(value){if(root.view==="settings")root.secretKeyDraft=value;else if(root.view!=="browser")root.query=value;else root.browserText=value}
        onDone:{if(root.view==="browser"&&root.browserText){root.browserAction({action:"text",text:root.browserText});root.browserAction({action:"key",key:"Enter"})}root.keyboardOpen=false;if(root.view!=="browser"&&root.view!=="settings")root.search(1)}
    }
    ChoicePicker {id:picker}
}
