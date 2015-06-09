var pictureSource;   // picture source
var destinationType; // sets the format of returned value 
var imagePath;
var imagePath1;
var imagePathPhotoLib;
var globalFileSystem = ''; 
var rootPath = "";
var dataToWrite; 
var imageName; 
var imageDirectory;
var folderName; 
 
$(document).ready(function() {
    document.addEventListener("deviceready", onDeviceReady, true);  
    $('#save_data').click(function() { 
    	var directory_name = 'test';
        var file_name = '10987.png'; 
        var img_data = imagePathPhotoLib; 
        console.log('Directory :==>> ' + directory_name + '==>> File: ==>>' + file_name + '==>> Image Data:==>> ' + img_data); 
        saveImageToFileSystem(directory_name, file_name, img_data);
    }); 
    
});
 
/* Initialize the file system  */
function onDeviceReady() {
	pictureSource=navigator.camera.PictureSourceType;
	//pictureSource=navigator.camera.PictureSourceType.CAMERA;
	destinationType=navigator.camera.DestinationType.FILE_URI;
	console.log('Getting File System access and File System root...');
	window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, checkAppRoot, createRootFail);
}

function checkAppRoot(fileSystem) {
	var entry = fileSystem.root;
	globalFileSystem = entry;
	entry.getDirectory(rootPath + 'Folder', {create: true, exclusive: false}, createRootSuccess, createRootFail);
}

function createRootSuccess(parent) { 
	global_fileSystem_path = parent + '/Folder';
}

function createRootFail(error) { 
	if(error.code == FileError.QUOTA_EXCEEDED_ERR) {
		alert("Memory full. Please submit/delete old data, free some space and relaunch this application.");
	} else {
		alert(error.code + ": Fatal error !! Cannot save images to local file system.");
	}
}

function dirFail(error) { 
	if(error.code == FileError.QUOTA_EXCEEDED_ERR) {
		alert("Memory full. Please submit/delete old data, free some space and relaunch this application.");
	} else {
		alert(error.code + ": Fatal error !! Cannot save images to local file system.");
	}
}

function saveImageToFileSystem(imgDirectory, imgFile, imageData) { 
	globalFileSystem.getDirectory(rootPath + 'Folder/'+imgDirectory, {create: true, exclusive: false}, createSuccess, dirFail); 
	globalFileSystem.getFile(rootPath + 'Folder/'+imgDirectory+'/' + imgFile, {create: true, exclusive: false}, function(fs) {
		imageDirectory = imgDirectory;
		imageName = imgFile;
		dataToWrite = imageData; 
		fs.createWriter(storeImageData, fileCreateFail);
	}, fileCreateFail);
}

function storeImageData(){ 
	  var url = dataToWrite; // image url
	  window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, function (fs) { 
	       var imagePath = fs.root.fullPath + "/"+'Folder/'+imageDirectory+ "/"+imageName; // full file path 
	       var fileTransfer = new FileTransfer();
	       
	       fileTransfer.download(url, imagePath, function (entry) {
	    	   
	    	   /******Code for single file delete******/
	    	   //var finalFilePath = entry.fullPath;
	    	   //filename = finalFilePath.substring(finalFilePath.lastIndexOf('/')+1);
	    	   //alert(filename); 
	    	   
	    	   /********Code for empty folder delete*******/
	    	   
	    	   var finalFilePath = entry.fullPath;
	    	   console.log("finalFilePath ==>>" + finalFilePath);  
	 	       document.getElementById('img1').src= finalFilePath;
	 	     
	      }, function (error) {
	           console.log("fileTransfer.download ==>> Some error");
	 	   });
	  });
}
 
function createSuccess(parent) {  
	console.log('Folder for ROUTE has been successfully created/folder already exists.');
}

function fileCreateFail(error) { 
	console.log(error.code + ': Fatal Error !! Image file for ROUTE ID ' + imgDirectory + ' cannot be created !!');
	if(error.code == FileError.QUOTA_EXCEEDED_ERR) {
		alert("Memory full. Please submit/delete old data, free some space and relaunch this application.");
	}
}


/******************Delete Folder from File system******************/

function removeFile() {
	var root = globalFileSystem; 
    window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, onFileSystemSuccess, fail);
    function fail(evt) {
        alert("FILE SYSTEM FAILURE ==>>" + evt.target.error.code);
    }
    function onFileSystemSuccess(fileSystem) {
    	var temp = 'Folder/'+ folderName; 
        fileSystem.root.getDirectory('Folder/'+ folderName,{create : true, exclusive : false},
            function(entry) {
            entry.removeRecursively(function() { 
                navigator.camera.cleanup(onSuccess, onFail); 
    			function onSuccess(){ 
    				console.log("Camera cleanup success.");
    			}
    			function onFail(message){ 
    				alert('Failed because: ' + message); 
    			} 
            }, fail);
        }, fail);
    }
}
 

/******************Delete single Folder from File system******************/

 
// remove file system entry
function removeFile() {
var root = globalFileSystem; 
 
var remove_file = function(entry) {
	entry.remove(function() { 
		console.log('Entry deleted : '+entry.toURI());
	}, onFileSystemError);
};

var onFileSystemError = function(error) {
	var msg = 'file system error: ' + error.code;
	navigator.notification.alert(msg, null, 'File System Error');
};
// retrieve a file and truncate it 
root.getFile('Folder/'+ filename, {create: false}, remove_file, onFileSystemError);
}
 


/******************Delete single file from File system******************/

 
//remove file system entry
function removeFile() {
var root = globalFileSystem; 

var remove_file = function(entry) {
	entry.remove(function() { 
		console.log('Entry deleted : '+entry.toURI());
	}, onFileSystemError);
};

var onFileSystemError = function(error) {
	var msg = 'file system error: ' + error.code;
	navigator.notification.alert(msg, null, 'File System Error');
};
//retrieve a file and truncate it  
root.getFile('Folder/'+imageDirectory+ "/"+ filename, {create: false}, remove_file, onFileSystemError);
} 

/******************CAPTURE PICTURE OR CHOOSE PICTURE FROM GALLERY*******************/


function capturePhoto() {
	 // Take picture using device camera and retrieve image as base64-encoded string
	navigator.camera.getPicture(onPhotoDataSuccess, onFail, {  
		sourceType :pictureSource, 
		quality: 75, 
		destinationType: destinationType, 
		allowEdit : true, 
		targetWidth: 200, 
		targetHeight: 200, 
		saveToPhotoAlbum: true, 
		encodingType: Camera.EncodingType.PNG,
	});
}

function onPhotoDataSuccess(imageData) {  
	imagePath1 = imageData;
	document.getElementById("smallImage").src=imageData;  
}
	  
function getPhoto(source) {
// Retrieve image file location from specified source
	navigator.camera.getPicture(onPhotoURISuccess, onFail, { quality: 50,
	     destinationType: destinationType.FILE_URI,
	     sourceType: source });
}

function onPhotoURISuccess(imageURI) {
	imagePathPhotoLib = imageURI; 
}

function onFail(message) {
	alert('Failed because : ' + message);
}


	
/*************************Get File Metadata and Directory information******************************************/
	
 
	var entry;

	//generic getById
	function getById(id) {
	    return document.querySelector(id);
	}
 
	//generic error handler
	function onError(e) {
	    getById("#content").innerHTML = "<h2>Error</h2>"+e.toString();
	} 
  
	function gotFiles(entries) {
	    var s = "";
	    for(var i=0,len=entries.length; i<len; i++) {
	        //entry objects include: isFile, isDirectory, name, fullPath
	        s+= entries[i].fullPath;
	        if (entries[i].isFile) {
	            s += " [F]";
	        }
	        else {
	            s += " [D]";
	        }
	        s += "<br/>";
	        
	    }
	    s+="<p/>";
	    console.log(s);
	}

	function doDirectoryListing(e) {
	    //get a directory reader from our FS
	    var dirReader = entry.root.createReader(); 
	    dirReader.readEntries(gotFiles,onError);        
	}

	function onFSSuccess(fileSystem) {
	    entry = fileSystem; 
	    getById("#dirListingButton").addEventListener("touchstart",doDirectoryListing);       
	    doDirectoryListing();
	}

	function onDeviceReady() { 
	    //request the persistent file system
	    window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, onFSSuccess, onError); 
	}

	function init() {
	    document.addEventListener("deviceready", onDeviceReady, true);
	} 
	
 
