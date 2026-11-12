import QtQuick

Rectangle {
    id: card
    property var book: ({})
    signal opened
    radius:14;color:"white";border.color:"black";border.width:2
    height:Math.max(230,details.implicitHeight+36)
    Rectangle {
        x:18;y:18;width:130;height:190;color:"#e9e9e9";radius:4
        AppText {anchors.centerIn:parent;width:parent.width-16;text:"No cover";horizontalAlignment:Text.AlignHCenter;font.pixelSize:18;color:"black";visible:cover.status!==Image.Ready}
        Image {id:cover;anchors.fill:parent;source:card.book.cover||"";fillMode:Image.PreserveAspectFit;asynchronous:true;visible:false;onStatusChanged:grayscale.requestPaint()}
        // CPU canvas also works with the tablet's software Qt Quick renderer.
        Canvas {
            id:grayscale;anchors.fill:parent
            property string imageURL:String(card.book.cover||"")
            onImageURLChanged:{if(imageURL)loadImage(imageURL);requestPaint()}
            Component.onCompleted:if(imageURL)loadImage(imageURL)
            onImageLoaded:requestPaint()
            onPaint:{
                var ctx=getContext("2d");ctx.reset()
                if(!imageURL||!isImageLoaded(imageURL)||cover.sourceSize.width<=0||cover.sourceSize.height<=0)return
                var ratio=Math.min(width/cover.sourceSize.width,height/cover.sourceSize.height)
                var w=cover.sourceSize.width*ratio,h=cover.sourceSize.height*ratio
                ctx.drawImage(imageURL,(width-w)/2,(height-h)/2,w,h)
                var pixels=ctx.getImageData(0,0,width,height),data=pixels.data
                for(var i=0;i<data.length;i+=4){var gray=Math.round(0.2126*data[i]+0.7152*data[i+1]+0.0722*data[i+2]);data[i]=gray;data[i+1]=gray;data[i+2]=gray}
                ctx.putImageData(pixels,0,0,0,0,width,height)
            }
        }
    }
    Column {
        id:details;x:170;y:18;width:parent.width-190;spacing:10
        AppText {width:parent.width;text:card.book.title||"Untitled";font.pixelSize:28;font.bold:true;wrapMode:Text.Wrap;textFormat:Text.PlainText}
        AppText {width:parent.width;text:card.book.author||"Author unavailable";font.pixelSize:23;wrapMode:Text.Wrap;textFormat:Text.PlainText}
        AppText {objectName:"bookMetadata";width:parent.width;text:[(card.book.format||"").toUpperCase(),card.book.size,card.book.pages?card.book.pages+" pages":"Pages unavailable",card.book.language].filter(Boolean).join(" | ");font.pixelSize:21;wrapMode:Text.Wrap;color:"black";textFormat:Text.PlainText}
        AppText {width:parent.width;text:[card.book.publisher,card.book.year].filter(Boolean).join(" | ");visible:text!=="";font.pixelSize:20;color:"black";wrapMode:Text.Wrap;textFormat:Text.PlainText}
    }
    MouseArea {anchors.fill:parent;onClicked:card.opened()}
}
