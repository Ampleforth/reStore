import QtQuick
import QtTest
import com.remarkable
import "../../qml" as Books

TestCase {
    name:"ImportAdapter"
    Books.NativeImport {id:bridge}
    SignalSpy {id:completed;target:bridge;signalName:"completed"}
    SignalSpy {id:failed;target:bridge;signalName:"failed"}
    function init(){completed.clear();failed.clear();DocumentImporter.accept=true;bridge.pendingURL=""}
    function test_passes_logical_folder_and_matches_decoded_url(){
        bridge.begin("file:///tmp/Against%20Intellectual%20Monopoly.pdf","folder-uuid","Book")
        compare(DocumentImporter.parentID,"folder-uuid")
        compare(DocumentImporter.urls[0],"file:///tmp/Against%20Intellectual%20Monopoly.pdf")
        DocumentImporter.finished("file:///tmp/Unrelated.pdf");compare(completed.count,0)
        DocumentImporter.finished("file:///tmp/Against Intellectual Monopoly.pdf")
        compare(completed.count,1);compare(bridge.pendingURL,"")
    }
    function test_failure_does_not_confirm_import(){
        bridge.begin("file:///tmp/Book.epub","","")
        DocumentImporter.failed("file:///tmp/Book.epub")
        DocumentImporter.finished("file:///tmp/Book.epub")
        compare(failed.count,1);compare(completed.count,0)
        DocumentImporter.accept=false
        bridge.begin("file:///tmp/Other.pdf","","")
        compare(failed.count,2);compare(completed.count,0)
    }
}
