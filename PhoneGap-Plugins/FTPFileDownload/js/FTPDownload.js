function fileDownload(){
	var args= null;
	console.log("Inside the fileDownload");
	cordova.exec(fileDownloadSuccess,  fileDownloadError, "FTPDownload", "getFile", [args]);
}

function fileDownloadSuccess(data){
	console.log("Inside the fileDownloadSuccess" + data);
	document.getElementById("imgtag").src=data; 
}

function fileDownloadError(data){
	console.log("Inside the fileDownloadError" + data);
}