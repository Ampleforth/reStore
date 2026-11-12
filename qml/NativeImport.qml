import QtQuick
import com.remarkable

Item {
    id: bridge
    property string pendingURL: ""
    property string title: ""
    signal completed
    signal failed(string message)
    function matches(url) {
        if(!pendingURL)return false
        try {return decodeURIComponent(String(url))===decodeURIComponent(pendingURL)}
        catch(e){return String(url)===pendingURL}
    }
    function begin(url, folder, name) {
        pendingURL=url;title=name
        try {
            if (!DocumentImporter.importFromUrls([url], folder)) {
                pendingURL="";failed("The reMarkable importer could not open this book")
            }
        } catch(e) {pendingURL="";failed("Native importer unavailable: "+String(e))}
    }
    Connections {
        target: DocumentImporter
        function onFinished(url) {if(bridge.matches(url)){bridge.pendingURL="";bridge.completed()}}
        function onFailed(url) {if(bridge.matches(url)){bridge.pendingURL="";bridge.failed("The reMarkable importer failed; the downloaded file has been retained")}}
    }
}
