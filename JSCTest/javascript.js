scriptObject = {
    data: "value",
    
    logInfo: function () {
        nativeObject.log("Called logInfo with data: " + this.data);
        return "loginfo return";
    },
    
    buttonPressed: function () {
        nativeObject.log("Called buttonPressed with data: " + this.data);
        return "buttonPressed return";
    }
}

scriptObject.logInfo();

nativeObject.log("running javascript");

nativeObject.test();

globalVariable = "global object string";

button.setTitle("Hello JavaScript");