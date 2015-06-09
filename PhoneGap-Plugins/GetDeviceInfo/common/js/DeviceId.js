function getDeviceID(){  
	cordova.exec( deviceInfoSuccess, deviceInfoFailure, "DeviceId","getId", [name]);
}

function deviceInfoSuccess(data) {
	var vendorId = data;
	console.log("DeviceInfoSuccess :" +  vendorId);
	return vendorId;
}

function deviceInfoFailure(data) {
	alert("DeviceInfoFailure :  " + data);
}