import QtQuick
import QtQuick.Window
import "../qml" as Books

Window {
    id:window;width:1404;height:1872;visible:true
    title:"reStore preview"
    function findItem(item,name){if(item.objectName===name)return item;for(var i=0;i<item.children.length;i++){var found=findItem(item.children[i],name);if(found)return found}return null}
    Books.Main {
        id:app;testing:true;anchors.fill:parent
        query:"intellectual property"
        message:"Preview · sample results and file metadata"
        books:[{title:"Against Intellectual Monopoly",author:"Michele Boldrin · David K. Levine",publisher:"Cambridge University Press",year:"2008",format:"pdf",size:"2.4 MB",pages:"298",language:"English [en]",cover:Qt.resolvedUrl("../docs/covers/against-monopoly.jpg"),url:"https://annas-archive.gl/md5/example"},
               {title:"Free Culture",author:"Lawrence Lessig",publisher:"Penguin Press",year:"2004",format:"epub",size:"1.8 MB",pages:"345",language:"English [en]",cover:Qt.resolvedUrl("../docs/covers/free-culture.jpg"),url:"https://annas-archive.gl/md5/example2"},
               {title:"The Public Domain",author:"James Boyle",publisher:"Yale University Press",year:"2008",format:"pdf",size:"3.1 MB",pages:"315",language:"English [en]",cover:Qt.resolvedUrl("../docs/covers/public-domain.jpg"),url:"https://annas-archive.gl/md5/example3"},
               {title:"The Wealth of Networks",author:"Yochai Benkler",publisher:"Yale University Press",year:"2006",format:"epub",size:"2.2 MB",pages:"515",language:"English [en]",cover:Qt.resolvedUrl("../docs/covers/wealth-networks.jpg"),url:"https://annas-archive.gl/md5/example4"},
               {title:"Against Intellectual Monopoly",author:"Michele Boldrin · David K. Levine",publisher:"Cambridge University Press",year:"2008",format:"epub",size:"1.2 MB",pages:"298",language:"English [en]",cover:Qt.resolvedUrl("../docs/covers/against-monopoly.jpg"),url:"https://annas-archive.gl/md5/example5"}]
        selectedBook:books[0]
        links:[{label:"Slow server 1 · waitlist",url:"https://example.org/slow/1"},{label:"Slow server 2 · no waitlist",url:"https://example.org/slow/2"},{label:"Slow server 3",url:"https://example.org/slow/3"}]
        selectedLink:links[0].url
        folders:[{id:"",name:"My files",parent:""},{id:"books",name:"Books",parent:""},{id:"fiction",name:"Fiction",parent:"books"},{id:"nonfiction",name:"Nonfiction",parent:"books"}]
        folderID:"books"
        view:Qt.application.arguments.indexOf("--home")>=0?"home":(Qt.application.arguments.indexOf("--book")>=0||Qt.application.arguments.indexOf("--links")>=0)?"book":(Qt.application.arguments.indexOf("--countdown")>=0||Qt.application.arguments.indexOf("--progress")>=0)?"download":Qt.application.arguments.indexOf("--folders")>=0?"settings":(Qt.application.arguments.indexOf("--browser")>=0||Qt.application.arguments.indexOf("--browser-keyboard")>=0)?"browser":"results"
        previousView:"results"
        browserImage:Qt.resolvedUrl("browser-preview.svg")
        browserURL:"https://annas-archive.gl/search?q=intellectual+property"
        keyboardOpen:Qt.application.arguments.indexOf("--keyboard")>=0||Qt.application.arguments.indexOf("--browser-keyboard")>=0
        folderOpen:Qt.application.arguments.indexOf("--folders")>=0
        downloadStatus:Qt.application.arguments.indexOf("--progress")>=0?({state:"downloading",bytes:2516582,total:4194304}):({state:"waiting",seconds:137})
        Component.onCompleted:{
            if(view==="home"){query="";message=""}
        }
    }
    Timer {interval:150;running:Qt.application.arguments.indexOf("--links")>=0;onTriggered:app.chooseLink(window.findItem(app,"linkDropdown"))}
    Timer {
        interval:600;running:true
        onTriggered:{
            var args=Qt.application.arguments, index=args.indexOf("--output")
            if(index>=0)window.contentItem.grabToImage(function(result){result.saveToFile(args[index+1]);Qt.quit()})
        }
    }
}
