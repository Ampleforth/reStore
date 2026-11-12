pragma Singleton
import QtQuick

QtObject {
    property var urls:[]
    property string parentID:""
    property bool accept:true
    signal finished(url source)
    signal failed(url source)
    function importFromUrls(values, parent){urls=values;parentID=parent;return accept}
}
