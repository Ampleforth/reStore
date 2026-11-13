import QtQuick
import QtQuick.Window
import QtTest
import "../../qml" as Books

TestCase {
    id:testCase
    name:"ArchiveBooks";when:windowShown;width:1000;height:1400;visible:true
    function initTestCase(){testCase.Window.window.width=width;testCase.Window.window.height=height;wait(50)}
    Component {id:appComponent;Books.Main {testing:true}}
    Component {id:folderComponent;Books.FolderPicker {width:1000;height:1400}}
    Component {id:keyboardComponent;Books.TouchKeyboard {onEdited:function(value){testCase.keyboardValue=value};onDone:testCase.keyboardDone=true}}
    Component {
        id:browserComponent
        Books.Main {
            testing:true;view:"browser";previousView:"results"
            browserImage:Qt.resolvedUrl("../../scripts/browser-preview.svg")
            function request(method,path,data,done){testCase.browserCalls=testCase.browserCalls.concat([{method:method,path:path,data:data}]);testCase.browserReply=done}
        }
    }
    Component {
        id:startupComponent
        Books.Main {
            testing:true
            property int settingsCalls:0
            property bool alwaysDisconnected:false
            function request(method,path,data,done,failed){
                settingsCalls++
                if(alwaysDisconnected||settingsCalls<3)failed("connection unavailable",0)
                else done({folder:"",folders:[{id:"",name:"My files",parent:""}],hasSecretKey:false})
            }
        }
    }
    property var app
    property string keyboardValue:""
    property bool keyboardDone:false
    property var browserCalls:[]
    property var browserReply:null
    function visibleItem(item,name){if(item.objectName===name&&item.visible)return item;for(var i=0;i<item.children.length;i++){var found=visibleItem(item.children[i],name);if(found)return found}return null}
    function init(){keyboardValue="";keyboardDone=false;browserCalls=[];browserReply=null;app=createTemporaryObject(appComponent,this,{width:1000,height:1400});verify(app!==null);wait(30)}
    function responseError(status,body,path){
        try {app.responseValue(status,body,path||"/search");fail("Expected response failure")}
        catch(error){return String(error)}
        return ""
    }
    function test_service_response_errors_are_actionable(){
        var error=responseError(0,"")
        verify(error.indexOf("Cannot connect")>=0);verify(error.indexOf("/search")>=0)
        verify(error.indexOf("SyntaxError")<0)
        error=responseError(404,"")
        verify(error.indexOf("empty response")>=0);verify(error.indexOf("HTTP 404")>=0)
        error=responseError(502,"<html>fixture-secret-key</html>")
        verify(error.indexOf("invalid response")>=0);verify(error.indexOf("fixture-secret-key")<0)
        for(var body of ["null","[]","123","true","\"hello\""]){
            verify(responseError(200,body).indexOf("unexpected response")>=0)
        }
        error=responseError(400,'{"error":"Browser exited; see runtime/engine.log"}',"/book")
        verify(error.indexOf("Browser exited")>=0);verify(error.indexOf("/book")>=0)
        compare(app.responseValue(200,'{"books":[]}',"/search").books.length,0)
    }
    function test_startup_recovers_when_backend_becomes_available(){
        var startup=createTemporaryObject(startupComponent,this)
        startup.loadSettings(true)
        verify(startup.busy)
        tryCompare(startup,"settingsCalls",3,2000)
        verify(!startup.busy);compare(startup.message,"");compare(startup.folders[0].name,"My files")
    }
    function test_startup_retry_is_bounded(){
        var startup=createTemporaryObject(startupComponent,this,{alwaysDisconnected:true})
        startup.loadSettings(true,10)
        compare(startup.settingsCalls,1);verify(!startup.busy)
        compare(startup.message,"connection unavailable")
    }
    function test_shutdown_cancels_startup_retry(){
        var startup=createTemporaryObject(startupComponent,this)
        startup.loadSettings(true);startup.unloading();wait(600)
        compare(startup.settingsCalls,1)
    }
    function test_home_and_search_keyboard(){
        compare(app.view,"home")
        mouseClick(findChild(app,"searchField"));verify(app.keyboardOpen)
        app.query="Against intellectual monopoly"
        verify(findChild(app,"searchButton").enabled)
        app.page=3
        findChild(app,"touchKeyboard").done()
        verify(!app.keyboardOpen);verify(app.busy);compare(app.page,1)
    }
    function test_dropdown_preserves_all_links(){
        app.view="book";app.selectedBook={title:"Example"}
        app.links=[{label:"Slow server 1",url:"https://example.org/1"},{label:"Slow server 2",url:"https://example.org/2"},{label:"Slow server 3",url:"https://example.org/3"}]
        app.selectedLink=app.links[0].url
        wait(30)
        var dropdown=findChild(app,"linkDropdown")
        mouseClick(dropdown)
        var list=findChild(app,"choiceList");compare(list.count,3)
        wait(30)
        mouseClick(list.itemAtIndex(1),60,30)
        compare(app.selectedLink,"https://example.org/2")
        verify(findChild(app,"downloadButton").enabled)
        verify(findChild(app,"downloadButton").y>dropdown.y)
    }
    function test_account_keyboard_and_fast_labels(){
        app.view="settings";app.query="Keep search query"
        mouseClick(findChild(app,"secretKeyField"));verify(app.keyboardOpen)
        var keyboard=findChild(app,"touchKeyboard")
        verify(!keyboard.secret)
        compare(findChild(keyboard,"keyboardInput").echoMode,TextInput.Normal)
        keyboard.edited("fixture-secret")
        compare(app.secretKeyDraft,"fixture-secret");compare(app.query,"Keep search query")
        verify(findChild(app,"secretKeyField").label.indexOf("fixture-secret")<0)
        keyboard.done();verify(!app.keyboardOpen);verify(!app.busy)
        verify(findChild(app,"saveAccountButton").enabled)
        app.view="book";app.downloadMode="fast";app.links=[]
        compare(app.linkLabel(),"Choose a fast download link")
    }
    function test_server_countdown(){
        app.view="download";app.downloadStatus={state:"waiting",seconds:125}
        compare(findChild(app,"countdown").text,"2:05")
        app.downloadStatus={state:"waiting",seconds:0}
        compare(findChild(app,"countdown").text,"0:00")
        compare(app.view,"download")
    }
    function test_logical_folder_navigation(){
        var picker=createTemporaryObject(folderComponent,this,{folders:[{id:"",name:"My files",parent:""},{id:"books",name:"Books",parent:""},{id:"fiction",name:"Fiction",parent:"books"}]})
        picker.current="fiction"
        wait(30)
        compare(picker.path(picker.current),"My files / Books / Fiction")
        mouseClick(findChild(picker,"parentFolder"));compare(picker.current,"books")
        mouseClick(findChild(picker,"parentFolder"));compare(picker.current,"")
    }
    function test_calendar_keyboard_edits_text(){
        app.visible=false
        var keyboard=createTemporaryObject(keyboardComponent,this,{width:1000})
        wait(30)
        mouseClick(findChild(keyboard,"key_a"));compare(keyboardValue,"a")
        mouseClick(visibleItem(keyboard,"shiftKey"));wait(10)
        mouseClick(findChild(keyboard,"key_B"));compare(keyboardValue,"aB")
        mouseClick(visibleItem(keyboard,"deleteKey"));compare(keyboardValue,"a")
        mouseClick(findChild(keyboard,"symbolModeButton"));wait(10)
        mouseClick(findChild(keyboard,"key_7"));compare(keyboardValue,"a7")
        mouseClick(findChild(keyboard,"spaceKey"));compare(keyboardValue,"a7 ")
        mouseClick(findChild(keyboard,"hideKeyboardButton"));verify(keyboardDone)
    }
    function test_browser_swipe_and_input_queue(){
        app.visible=false
        var browser=createTemporaryObject(browserComponent,this,{width:1000,height:1400})
        var gesture=findChild(browser,"browserGesture")
        tryVerify(function(){return gesture.width>0&&gesture.height>0})
        mouseDrag(gesture,gesture.width/2,gesture.height*0.75,0,-gesture.height*0.4,Qt.LeftButton,0,150)
        compare(browserCalls.length,1);compare(browserCalls[0].data.action,"scroll");verify(browserCalls[0].data.dy>0)
        browser.browserAction({action:"key",key:"Enter"})
        compare(browserCalls.length,1);compare(browser.browserActions.length,1)
        browserReply({image:browser.browserImage,url:"https://example.org"})
        compare(browserCalls.length,2);compare(browserCalls[1].data.key,"Enter")
        var help=findChild(browser,"captchaHelp"),frame=findChild(browser,"browserWindow")
        verify(help.text.indexOf("Continue at the top")>=0)
        verify(help.mapToItem(browser,0,help.height).y<frame.mapToItem(browser,0,0).y)
    }
    function test_browser_auto_continue(){
        app.visible=false
        var browser=createTemporaryObject(browserComponent,this,{width:1000,height:1400})
        browser.handleBrowserFrame({image:browser.browserImage,url:"https://example.org",verificationReady:false})
        compare(browser.view,"browser");compare(browserCalls.length,0)
        browser.query="example"
        browser.handleBrowserFrame({image:browser.browserImage,url:"https://example.org",verificationReady:true})
        compare(browser.view,"results");compare(browserCalls.length,1);compare(browserCalls[0].path,"/search")
    }
    function test_browser_text_focus_opens_keyboard(){
        app.visible=false
        var browser=createTemporaryObject(browserComponent,this,{width:1000,height:1400})
        browser.browserAction({action:"click",x:0.3,y:0.7})
        browserReply({image:browser.browserImage,url:"https://example.org",editableFocused:true})
        verify(browser.keyboardOpen)
    }
    function test_status_poll_keeps_button_appearance_stable(){
        app.visible=false
        var download=createTemporaryObject(browserComponent,this,{view:"download",width:1000,height:1400,downloadStatus:{state:"downloading",bytes:25,total:100}})
        var button=findChild(download,"bookDetailsButton"),color=String(button.color)
        download.checkDownload()
        verify(download.statusPolling);verify(!download.busy);verify(button.enabled);compare(String(button.color),color)
        download.checkDownload();compare(browserCalls.length,1)
        browserReply({state:"downloading",bytes:50,total:100})
        verify(!download.statusPolling);verify(button.enabled);compare(String(button.color),color)
        download.checkDownload();compare(browserCalls.length,2);compare(String(button.color),color)
        browserReply({state:"downloading",bytes:75,total:100})
        compare(String(button.color),color)
    }
    function test_download_completion_describes_import_destination(){
        app.view="download";app.folders=[{id:"",name:"My files",parent:""},{id:"books",name:"Books",parent:""},{id:"fiction",name:"Fiction",parent:"books"}];app.folderID="fiction"
        app.downloadStatus={state:"downloading",bytes:100,total:100}
        compare(findChild(app,"countdown").text,"Finishing download…")
        app.applyDownload({state:"complete",bytes:100,total:100});wait(20)
        verify(app.importing)
        compare(findChild(app,"countdown").text,"Importing into My files / Books / Fiction…")
        var track=findChild(app,"downloadProgress"),fill=findChild(app,"downloadProgressFill")
        verify(track.visible);compare(fill.width,track.width-4)
        verify(!findChild(app,"bookDetailsButton").enabled)
        // Some servers never provide a total. Import still means transfer finished.
        app.downloadStatus={state:"complete",bytes:100,total:0};wait(20)
        compare(fill.width,track.width-4)
    }
    function test_download_progress_and_shutdown(){
        app.view="download";app.downloadStatus={state:"downloading",bytes:25,total:100};wait(30)
        var track=findChild(app,"downloadProgress"),fill=findChild(app,"downloadProgressFill")
        verify(track.visible);compare(fill.width,(track.width-4)/4)
        app.unloading();verify(app.shuttingDown)
        app.unloading();verify(app.shuttingDown)
    }
    function test_fonts_and_plain_donation_text(){
        compare(findChild(app,"bodyFont").status,FontLoader.Ready)
        var donation=findChild(app,"donationText")
        var authors=findChild(app,"authorSupportText"),notices=findChild(app,"homeNotices")
        var library=findChild(app,"librarySupportText"),benefits=findChild(app,"membershipBenefitsText")
        verify(authors.text.indexOf("Authors deserve")>=0)
        verify(authors.text.indexOf("physical copy")>=0)
        verify(library.text.indexOf("if it can purchase a copy for the library")>=0)
        verify(authors.mapToItem(app,0,0).y<donation.mapToItem(app,0,0).y)
        verify(benefits.text.indexOf("fast downloads without a waitlist")>=0)
        verify(findChild(app,"membershipSetupText").text.indexOf("secret key in Settings")>=0)
        verify(findChild(app,"membershipCaveatText").text.indexOf("CAPTCHA verification may still be required")>=0)
        compare(authors.font.pixelSize,28);compare(benefits.font.pixelSize,26)
        compare(authors.textFormat,Text.PlainText)
        verify(notices.clip)
        app.anchors.fill=undefined;app.width=1000;app.height=900;wait(30)
        verify(notices.contentHeight>notices.height)
        notices.contentY=notices.contentHeight-notices.height
        verify(notices.contentY>0)
        compare(donation.textFormat,Text.PlainText)
    }
    function test_keyboard_keeps_bottom_of_browser_visible(){
        app.visible=false
        var browser=createTemporaryObject(browserComponent,this,{width:1000,height:1400})
        var frame=findChild(browser,"browserWindow"),image=findChild(browser,"browserFrameImage")
        tryVerify(function(){return image.status===Image.Ready})
        var fullHeight=frame.height,oldImageHeight=image.height
        browser.keyboardOpen=true;wait(30)
        verify(frame.height<=fullHeight/2)
        compare(image.height,oldImageHeight)
        compare(image.mapToItem(frame,0,image.height).y,frame.height-8)
        var keyboard=findChild(browser,"touchKeyboard")
        verify(frame.mapToItem(browser,0,frame.height).y<keyboard.y)
        verify(image.retainWhileLoading)
        browser.keyboardOpen=false;wait(30);compare(frame.height,fullHeight)
    }
}
