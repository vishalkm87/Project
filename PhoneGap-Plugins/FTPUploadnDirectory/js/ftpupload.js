 var pictureSource;
var destinationType;
var path='';
//var busyInd = new WL.BusyIndicator('content', {text : 'Loading...'});

document.addEventListener("deviceready",onDeviceReady,false);

function onDeviceReady() {
    pictureSource=navigator.camera.PictureSourceType;
    destinationType=navigator.camera.DestinationType;
}

function onPhotoURISuccess(imageURI) { 
   imagepath = imageURI;
   var len = imagepath.indexOf('/') + 2;
   var str = imagepath.substring(len); 
   path = str;
} 

function getPhoto(source) { 
	navigator.camera.getPicture(onPhotoURISuccess, onFail, { quality: 50,
	destinationType: destinationType.FILE_URI,
	sourceType: source }); 
}

function onFail(message) {
	alert('Failed because: ' + message);
}
 
function upload(){
	var args = {}; 
  args.address = "ftp://Admin@localhost/Documents/LocalFtp/";
  args.username = "Admin";
  args.password = "Google2014!";
  args.routeId = "906080"; 
  args.file = path; 
  cordova.exec(successCallback, failCallback, "FtpUpload", "sendFile", [args]);
}

function successCallback(data){   
	console.log('successCallback' + JSON.stringify(data));
}

function failCallback(data){  
	console.log('failCallback' + JSON.stringify(data));
}
 