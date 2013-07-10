package {
    import flash.display.BlendMode;
    import flash.display.DisplayObjectContainer;
    import flash.display.Loader;
    import flash.display.Stage;
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.errors.IOError;
    import flash.net.FileReferenceList;
    import flash.net.FileReference;
    import flash.net.FileFilter;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.net.URLRequestHeader;
    import flash.net.URLVariables;
    import flash.net.Socket;
    import flash.events.*;
    import flash.external.ExternalInterface;
    import flash.system.Security;
    import flash.text.AntiAliasType;
    import flash.text.GridFitType;
    import flash.text.StaticText;
    import flash.text.StyleSheet;
    import flash.text.TextDisplayMode;
    import flash.text.TextField;
    import flash.text.TextFieldType;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;
    import flash.ui.Mouse;
    import flash.utils.Timer;
    import flash.xml.XMLDocument;
    import flash.xml.XMLNode;
    import flash.xml.XMLNodeType;
    import flash.utils.ByteArray;
    import flash.utils.setTimeout;
    import flash.system.Security;

    import FileItem;
    import ExternalCall;
    import URLParser;

    [SWF(backgroundColor="#FFFFFF",frameRate="15",width="300",height="900")]
        public class SWFUpload extends Sprite {
            // Cause SWFUpload to start as soon as the movie starts
            public static function main():void
            {
                var SWFUpload:SWFUpload = new SWFUpload();
            }

            private const build_number:String = "SWFUPLOAD 2.2.1";

            // State tracking variables
            private var fileBrowserMany:FileReferenceList = new FileReferenceList();
            private var fileBrowserOne:FileReference = null;	// This isn't set because it can't be reused like the FileReferenceList. It gets setup in the SelectFile method

            private var file_queue:Array = new Array();		// holds a list of all items that are to be uploaded.
            private var current_file_item:FileItem = null;	// the item that is currently being uploaded.

            private var file_index:Array = new Array();

            private var successful_uploads:Number = 0;		// Tracks the uploads that have been completed
            private var queue_errors:Number = 0;			// Tracks files rejected during queueing
            private var upload_errors:Number = 0;			// Tracks files that fail upload
            private var upload_cancelled:Number = 0;		// Tracks number of cancelled files
            private var queued_uploads:Number = 0;			// Tracks the FileItems that are waiting to be uploaded.

            private var valid_file_extensions:Array = new Array();// Holds the parsed valid extensions.

            private var serverDataTimer:Timer = null;
            private var assumeSuccessTimer:Timer = null;

            private var restoreExtIntTimer:Timer;
            private var hasCalledFlashReady:Boolean = false;

            // Callbacks
            private var flashReady_Callback:String;
            private var fileDialogStart_Callback:String;
            private var fileQueued_Callback:String;
            private var fileQueueError_Callback:String;
            private var fileDialogComplete_Callback:String;

            private var uploadStart_Callback:String;
            private var uploadProgress_Callback:String;
            private var uploadError_Callback:String;
            private var uploadSuccess_Callback:String;

            private var uploadComplete_Callback:String;

            private var debug_Callback:String;
            private var testExternalInterface_Callback:String;
            private var cleanUp_Callback:String;
            private var buttonAction_Callback:String;

            // Values passed in from the HTML
            private var movieName:String;
            private var uploadURL:String;
            private var filePostName:String;
            private var uploadPostObject:Object;
            private var fileTypes:String;
            private var fileTypesDescription:String;
            private var fileSizeLimit:Number;
            private var fileUploadLimit:Number = 0;
            private var fileQueueLimit:Number = 0;
            private var useQueryString:Boolean = false;
            private var requeueOnError:Boolean = false;
            private var httpSuccess:Array = [];
            private var assumeSuccessTimeout:Number = 0;
            private var debugEnabled:Boolean;


            // MultiPart and Chunk Data
            private var useChunk: Boolean = false;
            private var useMultiPart: Boolean = false;
            private var chunkSize:uint = 33554432; // 32 MB
            private var useSocket: Boolean = false;

            // Custom Headers
            private var headers: Object;

            private var uploadURLParsed: Object;

            private var buttonLoader:Loader;
            private var buttonTextField:TextField;
            private var buttonCursorSprite:Sprite;
            private var buttonImageURL:String;
            private var buttonWidth:Number;
            private var buttonHeight:Number;
            private var buttonText:String;
            private var buttonTextStyle:String;
            private var buttonTextTopPadding:Number;
            private var buttonTextLeftPadding:Number;
            private var buttonAction:Number;
            private var buttonCursor:Number;
            private var buttonStateOver:Boolean;
            private var buttonStateMouseDown:Boolean;
            private var buttonStateDisabled:Boolean;

            // Error code "constants"
            // Size check constants
            private var SIZE_TOO_BIG:Number		= 1;
            private var SIZE_ZERO_BYTE:Number	= -1;
            private var SIZE_OK:Number			= 0;

            // Queue errors
            private var ERROR_CODE_QUEUE_LIMIT_EXCEEDED:Number 			= -100;
            private var ERROR_CODE_FILE_EXCEEDS_SIZE_LIMIT:Number 		= -110;
            private var ERROR_CODE_ZERO_BYTE_FILE:Number 				= -120;
            private var ERROR_CODE_INVALID_FILETYPE:Number          	= -130;

            // Upload Errors
            private var ERROR_CODE_HTTP_ERROR:Number 					= -200;
            private var ERROR_CODE_MISSING_UPLOAD_URL:Number        	= -210;
            private var ERROR_CODE_IO_ERROR:Number 						= -220;
            private var ERROR_CODE_SECURITY_ERROR:Number 				= -230;
            private var ERROR_CODE_UPLOAD_LIMIT_EXCEEDED:Number			= -240;
            private var ERROR_CODE_UPLOAD_FAILED:Number 				= -250;
            private var ERROR_CODE_SPECIFIED_FILE_ID_NOT_FOUND:Number 	= -260;
            private var ERROR_CODE_FILE_VALIDATION_FAILED:Number		= -270;
            private var ERROR_CODE_FILE_CANCELLED:Number				= -280;
            private var ERROR_CODE_UPLOAD_STOPPED:Number				= -290;


            // Button Actions
            private var BUTTON_ACTION_SELECT_FILE:Number                = -100;
            private var BUTTON_ACTION_SELECT_FILES:Number               = -110;
            private var BUTTON_ACTION_START_UPLOAD:Number               = -120;
            private var BUTTON_ACTION_JAVASCRIPT:Number					= -130;

            private var BUTTON_CURSOR_ARROW:Number						= -1;
            private var BUTTON_CURSOR_HAND:Number						= -2;

            private var SOCKET_PORT:Number = 80;


            private var FORB_HEADER: String = "host,referer,origin,content-type,content-length,content-disposition,user-agent";

            public function SWFUpload() {
                // Do the feature detection.  Make sure this version of Flash supports the features we need. If not
                // abort initialization.
                if (!flash.net.FileReferenceList || !flash.net.FileReference || !flash.net.URLRequest || !flash.external.ExternalInterface || !flash.external.ExternalInterface.available || !DataEvent.UPLOAD_COMPLETE_DATA) {
                    return;
                }

                // Keep Flash Player busy so it doesn't show the "flash script is running slowly" error
                var counter:Number = 0;
                root.addEventListener(Event.ENTER_FRAME, function ():void { if (++counter > 100) counter = 0; });

                // Setup file FileReferenceList events
                this.fileBrowserMany.addEventListener(Event.SELECT, this.Select_Many_Handler);
                this.fileBrowserMany.addEventListener(Event.CANCEL,  this.DialogCancelled_Handler);


                this.stage.align = StageAlign.TOP_LEFT;
                this.stage.scaleMode = StageScaleMode.NO_SCALE;			

                // Setup the button and text label
                this.buttonLoader = new Loader();
                var doNothing:Function = function ():void { };
                this.buttonLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, doNothing );
                this.buttonLoader.contentLoaderInfo.addEventListener(HTTPStatusEvent.HTTP_STATUS, doNothing );
                this.stage.addChild(this.buttonLoader);

                var self:SWFUpload = this;

                this.stage.addEventListener(MouseEvent.CLICK, function (event:MouseEvent):void {
                        self.UpdateButtonState();
                        self.ButtonClickHandler(event);
                        });
                this.stage.addEventListener(MouseEvent.MOUSE_DOWN, function (event:MouseEvent):void {
                        self.buttonStateMouseDown = true;
                        self.UpdateButtonState();
                        });
                this.stage.addEventListener(MouseEvent.MOUSE_UP, function (event:MouseEvent):void {
                        self.buttonStateMouseDown = false;
                        self.UpdateButtonState();
                        });
                this.stage.addEventListener(MouseEvent.MOUSE_OVER, function (event:MouseEvent):void {
                        self.buttonStateMouseDown = event.buttonDown;
                        self.buttonStateOver = true;
                        self.UpdateButtonState();
                        });
                this.stage.addEventListener(MouseEvent.MOUSE_OUT, function (event:MouseEvent):void {
                        self.buttonStateMouseDown = false;
                        self.buttonStateOver = false;
                        self.UpdateButtonState();
                        });
                // Handle the mouse leaving the flash movie altogether
                this.stage.addEventListener(Event.MOUSE_LEAVE, function (event:Event):void {
                        self.buttonStateMouseDown = false;
                        self.buttonStateOver = false;
                        self.UpdateButtonState();
                        });

                this.buttonTextField = new TextField();
                this.buttonTextField.type = TextFieldType.DYNAMIC;
                this.buttonTextField.antiAliasType = AntiAliasType.ADVANCED;
                this.buttonTextField.autoSize = TextFieldAutoSize.NONE;
                this.buttonTextField.cacheAsBitmap = true;
                this.buttonTextField.multiline = true;
                this.buttonTextField.wordWrap = false;
                this.buttonTextField.tabEnabled = false;
                this.buttonTextField.background = false;
                this.buttonTextField.border = false;
                this.buttonTextField.selectable = false;
                this.buttonTextField.condenseWhite = true;

                this.stage.addChild(this.buttonTextField);


                this.buttonCursorSprite = new Sprite();
                this.buttonCursorSprite.graphics.beginFill(0xFFFFFF, 0);
                this.buttonCursorSprite.graphics.drawRect(0, 0, 1, 1);
                this.buttonCursorSprite.graphics.endFill();
                this.buttonCursorSprite.buttonMode = true;
                this.buttonCursorSprite.x = 0;
                this.buttonCursorSprite.y = 0;
                this.buttonCursorSprite.addEventListener(MouseEvent.CLICK, doNothing);
                this.stage.addChild(this.buttonCursorSprite);

                // Get the movie name
                this.movieName = root.loaderInfo.parameters.movieName || '';
                this.movieName = this.movieName.replace(/[^a-zA-Z0-9\_\.\-]/g, "");

                // **Configure the callbacks**
                // The JavaScript tracks all the instances of SWFUpload on a page.  We can access the instance
                // associated with this SWF file using the movieName.  Each callback is accessible by making
                // a call directly to it on our instance.  There is no error handling for undefined callback functions.
                // A developer would have to deliberately remove the default functions,set the variable to null, or remove
                // it from the init function.
                this.flashReady_Callback         = "SWFUpload.instances[\"" + this.movieName + "\"].flashReady";
                this.fileDialogStart_Callback    = "SWFUpload.instances[\"" + this.movieName + "\"].fileDialogStart";
                this.fileQueued_Callback         = "SWFUpload.instances[\"" + this.movieName + "\"].fileQueued";
                this.fileQueueError_Callback     = "SWFUpload.instances[\"" + this.movieName + "\"].fileQueueError";
                this.fileDialogComplete_Callback = "SWFUpload.instances[\"" + this.movieName + "\"].fileDialogComplete";

                this.uploadStart_Callback        = "SWFUpload.instances[\"" + this.movieName + "\"].uploadStart";
                this.uploadProgress_Callback     = "SWFUpload.instances[\"" + this.movieName + "\"].uploadProgress";
                this.uploadError_Callback        = "SWFUpload.instances[\"" + this.movieName + "\"].uploadError";
                this.uploadSuccess_Callback      = "SWFUpload.instances[\"" + this.movieName + "\"].uploadSuccess";

                this.uploadComplete_Callback     = "SWFUpload.instances[\"" + this.movieName + "\"].uploadComplete";

                this.debug_Callback              = "SWFUpload.instances[\"" + this.movieName + "\"].debug";

                this.testExternalInterface_Callback = "SWFUpload.instances[\"" + this.movieName + "\"].testExternalInterface";
                this.cleanUp_Callback            = "SWFUpload.instances[\"" + this.movieName + "\"].cleanUp";
                this.buttonAction_Callback       = "SWFUpload.instances[\"" + this.movieName + "\"].buttonAction";

                // Get the Flash Vars
                this.uploadURL = root.loaderInfo.parameters.uploadURL;
                try {
                    uploadURLParsed = URLParser.parse(this.uploadURL);
                    if (uploadURLParsed.protocol != "") {
                        Security.loadPolicyFile(uploadURLParsed.protocol + "://" + uploadURLParsed.host + uploadURLParsed.port + "/crossdomain.xml");
                    }
                    var localPolicy: Object = URLParser.parse(this.loaderInfo.url);
                    Security.loadPolicyFile(localPolicy.protocol + "://" + localPolicy.host + (localPolicy.port != "" ? ":" + localPolicy.port : "") + "/crossdomain.xml");
                } catch(e: Error) {
                }

                this.filePostName = root.loaderInfo.parameters.filePostName;
                this.fileTypes = root.loaderInfo.parameters.fileTypes;
                this.fileTypesDescription = root.loaderInfo.parameters.fileTypesDescription + " (" + this.fileTypes + ")";
                this.loadPostParams(root.loaderInfo.parameters.params);

                // load custom headers
                this.loadHeaders(root.loaderInfo.parameters.headers);

                if (!this.filePostName) {
                    this.filePostName = "Filedata";
                }
                if (!this.fileTypes) {
                    this.fileTypes = "*.*";
                }
                if (!this.fileTypesDescription) {
                    this.fileTypesDescription = "All Files";
                }

                this.LoadFileExensions(this.fileTypes);

                try {
                    this.debugEnabled = root.loaderInfo.parameters.debugEnabled == "true" ? true : false;
                } catch (ex:Object) {
                    this.debugEnabled = false;
                }

                try {
                    this.fileSizeLimit = this.getSize(String(root.loaderInfo.parameters.fileSizeLimit));
                } catch (ex:Object) {
                    this.fileSizeLimit = 0;
                }


                try {
                    this.fileUploadLimit = Number(root.loaderInfo.parameters.fileUploadLimit);
                    if (this.fileUploadLimit < 0) this.fileUploadLimit = 0;
                } catch (ex:Object) {
                    this.fileUploadLimit = 0;
                }

                try {
                    this.fileQueueLimit = Number(root.loaderInfo.parameters.fileQueueLimit);
                    if (this.fileQueueLimit < 0) this.fileQueueLimit = 0;
                } catch (ex:Object) {
                    this.fileQueueLimit = 0;
                }

                // Using new Multipart method
                try {
                    this.useMultiPart = (String(root.loaderInfo.parameters.useMultiPart) == "true");
                } catch (ex:Object) {
                    this.useMultiPart = false;
                }

                // Chunking is only possible with multipart contents
                try {
                    this.useChunk = ((String(root.loaderInfo.parameters.useChunk) == "true"));
                } catch (ex:Object) {
                    this.useChunk = false;
                }

                try {
                    this.chunkSize = this.getSize(String(root.loaderInfo.parameters.chunkSize));
                } catch(ex:Object) {
                    this.chunkSize = this.getSize("32 MB");
                }

                try {
                    this.useSocket = (String(root.loaderInfo.parameters.useSocket) == "true");
                } catch(ex:Object) {
                    this.useSocket = false;
                }

                // Set the queue limit to match the upload limit when the queue limit is bigger than the upload limit
                if (this.fileQueueLimit > this.fileUploadLimit && this.fileUploadLimit != 0) this.fileQueueLimit = this.fileUploadLimit;
                // The the queue limit is unlimited and the upload limit is not then set the queue limit to the upload limit
                if (this.fileQueueLimit == 0 && this.fileUploadLimit != 0) this.fileQueueLimit = this.fileUploadLimit;

                try {
                    this.useQueryString = root.loaderInfo.parameters.useQueryString == "true" ? true : false;
                } catch (ex:Object) {
                    this.useQueryString = false;
                }

                try {
                    this.requeueOnError = root.loaderInfo.parameters.requeueOnError == "true" ? true : false;
                } catch (ex:Object) {
                    this.requeueOnError = false;
                }

                try {
                    this.SetHTTPSuccess(String(root.loaderInfo.parameters.httpSuccess));
                } catch (ex:Object) {
                    this.SetHTTPSuccess([]);
                }

                try {
                    this.SetAssumeSuccessTimeout(Number(root.loaderInfo.parameters.assumeSuccessTimeout));
                } catch (ex:Object) {
                    this.SetAssumeSuccessTimeout(0);
                }


                try {
                    this.SetButtonDimensions(Number(root.loaderInfo.parameters.buttonWidth), Number(root.loaderInfo.parameters.buttonHeight));
                } catch (ex:Object) {
                    this.SetButtonDimensions(0, 0);
                }

                try {
                    this.SetButtonImageURL(String(root.loaderInfo.parameters.buttonImageURL));
                } catch (ex:Object) {
                    this.SetButtonImageURL("");
                }

                try {
                    this.SetButtonText(String(root.loaderInfo.parameters.buttonText));
                    // HTML-escape strings that come from the user, preventing XSS.
                    this.SetButtonText(htmlEscape(String(root.loaderInfo.parameters.buttonText)));
                } catch (ex:Object) {
                    this.SetButtonText("");
                }

                try {
                    this.SetButtonTextPadding(Number(root.loaderInfo.parameters.buttonTextLeftPadding), Number(root.loaderInfo.parameters.buttonTextTopPadding));
                } catch (ex:Object) {
                    this.SetButtonTextPadding(0, 0);
                }

                try {
                    this.SetButtonTextStyle(String(root.loaderInfo.parameters.buttonTextStyle));
                } catch (ex:Object) {
                    this.SetButtonTextStyle("");
                }

                try {
                    this.SetButtonAction(Number(root.loaderInfo.parameters.buttonAction));
                } catch (ex:Object) {
                    this.SetButtonAction(this.BUTTON_ACTION_SELECT_FILES);
                }

                try {
                    this.SetButtonDisabled(root.loaderInfo.parameters.buttonDisabled == "true" ? true : false);
                } catch (ex:Object) {
                    this.SetButtonDisabled(Boolean(false));
                }

                try {
                    this.SetButtonCursor(Number(root.loaderInfo.parameters.buttonCursor));
                } catch (ex:Object) {
                    this.SetButtonCursor(this.BUTTON_CURSOR_ARROW);
                }

                this.SetupExternalInterface();

                this.Debug("SWFUpload Init Complete");
                this.PrintDebugInfo();

                if (ExternalCall.Bool(this.testExternalInterface_Callback)) {
                    ExternalCall.Simple(this.flashReady_Callback);
                    this.hasCalledFlashReady = true;
                }

                // Start periodically checking the external interface
                var oSelf:SWFUpload = this;
                this.restoreExtIntTimer = new Timer(1000, 0);
                this.restoreExtIntTimer.addEventListener(TimerEvent.TIMER, function ():void { oSelf.CheckExternalInterface();} );
                this.restoreExtIntTimer.start();
            }

            // Used to periodically check that the External Interface functions are still working
            private function CheckExternalInterface():void {
                if (!ExternalCall.Bool(this.testExternalInterface_Callback)) {
                    this.SetupExternalInterface();
                    this.Debug("ExternalInterface reinitialized");
                    if (!this.hasCalledFlashReady) {
                        ExternalCall.Simple(this.flashReady_Callback);
                        this.hasCalledFlashReady = true;
                    }
                }
            }

            private function StopExternalInterfaceCheck():void {
                if (this.restoreExtIntTimer) {
                    this.restoreExtIntTimer.start();
                    this.restoreExtIntTimer = null;
                }
            }

            // Called by JS to see if it can access the external interface
            private function TestExternalInterface():Boolean {
                return true;
            }

            private function SetupExternalInterface():void {
                try {
                    ExternalInterface.addCallback("SelectFile", this.SelectFile);
                    ExternalInterface.addCallback("SelectFiles", this.SelectFiles);
                    ExternalInterface.addCallback("StartUpload", this.StartUpload);
                    ExternalInterface.addCallback("ReturnUploadStart", this.ReturnUploadStart);
                    ExternalInterface.addCallback("StopUpload", this.StopUpload);
                    ExternalInterface.addCallback("CancelUpload", this.CancelUpload);
                    ExternalInterface.addCallback("RequeueUpload", this.RequeueUpload);

                    ExternalInterface.addCallback("GetStats", this.GetStats);
                    ExternalInterface.addCallback("SetStats", this.SetStats);
                    ExternalInterface.addCallback("GetFile", this.GetFile);
                    ExternalInterface.addCallback("GetFileByIndex", this.GetFileByIndex);

                    ExternalInterface.addCallback("AddFileParam", this.AddFileParam);
                    ExternalInterface.addCallback("RemoveFileParam", this.RemoveFileParam);

                    ExternalInterface.addCallback("SetUploadURL", this.SetUploadURL);
                    ExternalInterface.addCallback("SetPostParams", this.SetPostParams);
                    ExternalInterface.addCallback("SetFileTypes", this.SetFileTypes);
                    ExternalInterface.addCallback("SetFileSizeLimit", this.SetFileSizeLimit);
                    ExternalInterface.addCallback("SetFileUploadLimit", this.SetFileUploadLimit);
                    ExternalInterface.addCallback("SetFileQueueLimit", this.SetFileQueueLimit);
                    ExternalInterface.addCallback("SetFilePostName", this.SetFilePostName);
                    ExternalInterface.addCallback("SetUseQueryString", this.SetUseQueryString);
                    ExternalInterface.addCallback("SetRequeueOnError", this.SetRequeueOnError);
                    ExternalInterface.addCallback("SetHTTPSuccess", this.SetHTTPSuccess);
                    ExternalInterface.addCallback("SetAssumeSuccessTimeout", this.SetAssumeSuccessTimeout);
                    ExternalInterface.addCallback("SetDebugEnabled", this.SetDebugEnabled);

                    ExternalInterface.addCallback("SetButtonImageURL", this.SetButtonImageURL);
                    ExternalInterface.addCallback("SetButtonDimensions", this.SetButtonDimensions);
                    ExternalInterface.addCallback("SetButtonText", this.SetButtonText);
                    ExternalInterface.addCallback("SetButtonTextPadding", this.SetButtonTextPadding);
                    ExternalInterface.addCallback("SetButtonTextStyle", this.SetButtonTextStyle);
                    ExternalInterface.addCallback("SetButtonAction", this.SetButtonAction);
                    ExternalInterface.addCallback("SetButtonDisabled", this.SetButtonDisabled);
                    ExternalInterface.addCallback("SetButtonCursor", this.SetButtonCursor);

                    ExternalInterface.addCallback("TestExternalInterface", this.TestExternalInterface);
                    ExternalInterface.addCallback("StopExternalInterfaceCheck", this.StopExternalInterfaceCheck);

                } catch (ex:Error) {
                    this.Debug("Callbacks where not set: " + ex.message);
                    return;
                }

                ExternalCall.Simple(this.cleanUp_Callback);
            }

            /* *****************************************
             * FileReference Event Handlers
             * *************************************** */
            private function DialogCancelled_Handler(event:Event):void {
                this.Debug("Event: fileDialogComplete: File Dialog window cancelled.");
                ExternalCall.FileDialogComplete(this.fileDialogComplete_Callback, 0, 0, this.queued_uploads);
            }

            private function Open_Handler(event:Event):void {
                this.Debug("Event: uploadProgress (OPEN): File ID: " + this.current_file_item.id);
                if (!this.useMultiPart ||  this.current_file_item.chunk === 0)
                {
                    ExternalCall.UploadProgress(this.uploadProgress_Callback, this.current_file_item.ToJavaScriptObject(), 0, this.current_file_item.file_reference.size);
                }
            }

            private function FileProgress_Handler(event:ProgressEvent):void {
                // On early than Mac OS X 10.3 bytesLoaded is always -1, convert this to zero. Do bytesTotal for good measure.
                //  http://livedocs.adobe.com/flex/3/langref/flash/net/FileReference.html#event:progress
                var bytesLoaded:Number = event.bytesLoaded < 0 ? 0 : event.bytesLoaded;
                var bytesTotal:Number = event.bytesTotal < 0 ? 0 : event.bytesTotal;

                // Because Flash never fires a complete event if the server doesn't respond after 30 seconds or on Macs if there
                // is no content in the response we'll set a timer and assume that the upload is successful after the defined amount of
                // time.  If the timeout is zero then we won't use the timer.
                if (bytesLoaded === bytesTotal && bytesTotal > 0 && this.assumeSuccessTimeout > 0) {
                    if (this.assumeSuccessTimer !== null) {
                        this.assumeSuccessTimer.stop();
                        this.assumeSuccessTimer = null;
                    }

                    this.assumeSuccessTimer = new Timer(this.assumeSuccessTimeout * 1000, 1);
                    this.assumeSuccessTimer.addEventListener(TimerEvent.TIMER_COMPLETE, AssumeSuccessTimer_Handler);
                    this.assumeSuccessTimer.start();
                }

                this.Debug("Event: uploadProgress: File ID: " + this.current_file_item.id + ". Bytes: " + bytesLoaded + ". Total: " + bytesTotal);
                ExternalCall.UploadProgress(this.uploadProgress_Callback, this.current_file_item.ToJavaScriptObject(), bytesLoaded, bytesTotal);
            }

            private function AssumeSuccessTimer_Handler(event:TimerEvent):void {
                this.Debug("Event: AssumeSuccess: " + this.assumeSuccessTimeout + " passed without server response");
                this.UploadSuccess(this.current_file_item, "", false);
            }

            private function Complete_Handler(event:Event):void {
                /* Because we can't do COMPLETE or DATA events (we have to do both) we can't
                 * just call uploadSuccess from the complete handler, we have to wait for
                 * the Data event which may never come. However, testing shows it always comes
                 * within a couple milliseconds if it is going to come so the solution is:
                 * 
                 * Set a timer in the COMPLETE event (which always fires) and if DATA is fired
                 * it will stop the timer and call uploadComplete
                 * 
                 * If the timer expires then DATA won't be fired and we call uploadComplete
                 * */

                // Set the timer
                if (serverDataTimer != null) {
                    this.serverDataTimer.stop();
                    this.serverDataTimer = null;
                }

                this.serverDataTimer = new Timer(100, 1);
                //var self:SWFUpload = this;
                this.serverDataTimer.addEventListener(TimerEvent.TIMER, this.ServerDataTimer_Handler);
                this.serverDataTimer.start();
            }
            private function ServerDataTimer_Handler(event:TimerEvent):void {
                this.UploadSuccess(this.current_file_item, "");
            }

            private function ServerData_Handler(event:DataEvent):void {
                this.UploadSuccess(this.current_file_item, event.data);
            }

            private function UploadSuccess(file:FileItem, serverData:String, responseReceived:Boolean = true):void {
                if (this.serverDataTimer !== null) {
                    this.serverDataTimer.stop();
                    this.serverDataTimer = null;
                }
                if (this.assumeSuccessTimer !== null) {
                    this.assumeSuccessTimer.stop();
                    this.assumeSuccessTimer = null;
                }

                this.successful_uploads++;
                file.file_status = FileItem.FILE_STATUS_SUCCESS;

                this.Debug("Event: uploadSuccess: File ID: " + file.id + " Response Received: " + responseReceived.toString() + " Data: " + serverData);
                ExternalCall.UploadSuccess(this.uploadSuccess_Callback, file.ToJavaScriptObject(), serverData, responseReceived);

                this.UploadComplete(false);

            }

            private function HTTPError_Handler(event:HTTPStatusEvent):void {
                var isSuccessStatus:Boolean = false;
                for (var i:Number = 0; i < this.httpSuccess.length; i++) {
                    if (this.httpSuccess[i] === event.status) {
                        isSuccessStatus = true;
                        break;
                    }
                }

                if (isSuccessStatus) {
                    if (!this.useMultiPart)
                    {
                        this.Debug("Event: httpError: Translating status code " + event.status + " to uploadSuccess");

                        var serverDataEvent:DataEvent = new DataEvent(DataEvent.UPLOAD_COMPLETE_DATA, event.bubbles, event.cancelable, "");
                        this.ServerData_Handler(serverDataEvent);
                    }
                } else {
                    this.upload_errors++;
                    this.current_file_item.file_status = FileItem.FILE_STATUS_ERROR;

                    this.Debug("Event: uploadError: HTTP ERROR : File ID: " + this.current_file_item.id + ". HTTP Status: " + event.status + ".");
                    ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_HTTP_ERROR, this.current_file_item.ToJavaScriptObject(), event.status.toString());
                    this.UploadComplete(true); 	// An IO Error is also called so we don't want to complete the upload yet.
                }
            }

            // Note: Flash Player does not support Uploads that require authentication. Attempting this will trigger an
            // IO Error or it will prompt for a username and password and may crash the browser (FireFox/Opera)
            private function IOError_Handler(event:IOErrorEvent):void {
                // Only trigger an IO Error event if we haven't already done an HTTP error
                if (this.current_file_item.file_status != FileItem.FILE_STATUS_ERROR) {
                    this.upload_errors++;
                    this.current_file_item.file_status = FileItem.FILE_STATUS_ERROR;

                    this.Debug("Event: uploadError : IO Error : File ID: " + this.current_file_item.id + ". IO Error: " + event.text);
                    ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_IO_ERROR, this.current_file_item.ToJavaScriptObject(), event.text);
                }

                this.UploadComplete(true);
            }

            private function SecurityError_Handler(event:SecurityErrorEvent):void {
                this.upload_errors++;
                this.current_file_item.file_status = FileItem.FILE_STATUS_ERROR;

                this.Debug("Event: uploadError : Security Error : File Number: " + this.current_file_item.id + ". Error text: " + event.text);
                ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_SECURITY_ERROR, this.current_file_item.ToJavaScriptObject(), event.text);

                this.UploadComplete(true);
            }

            private function Select_Many_Handler(event:Event):void {
                this.Select_Handler(this.fileBrowserMany.fileList);
            }
            private function Select_One_Handler(event:Event):void {
                var fileArray:Array = new Array(1);
                fileArray[0] = this.fileBrowserOne;
                this.Select_Handler(fileArray);
            }

            private function Select_Handler(file_reference_list:Array):void {
                this.Debug("Select Handler: Received the files selected from the dialog. Processing the file list...");

                var num_files_queued:Number = 0;

                // Determine how many queue slots are remaining (check the unlimited (0) settings, successful uploads and queued uploads)
                var queue_slots_remaining:Number = 0;
                if (this.fileUploadLimit == 0) {
                    queue_slots_remaining = this.fileQueueLimit == 0 ? file_reference_list.length : (this.fileQueueLimit - this.queued_uploads);	// If unlimited queue make the allowed size match however many files were selected.
                } else {
                    var remaining_uploads:Number = this.fileUploadLimit - this.successful_uploads - this.queued_uploads;
                    if (remaining_uploads < 0) remaining_uploads = 0;
                    if (this.fileQueueLimit == 0 || this.fileQueueLimit >= remaining_uploads) {
                        queue_slots_remaining = remaining_uploads;
                    } else if (this.fileQueueLimit < remaining_uploads) {
                        queue_slots_remaining = this.fileQueueLimit - this.queued_uploads;
                    }
                }

                if (queue_slots_remaining < 0) queue_slots_remaining = 0;

                // Check if the number of files selected is greater than the number allowed to queue up.
                if (queue_slots_remaining < file_reference_list.length) {
                    this.Debug("Event: fileQueueError : Selected Files (" + file_reference_list.length + ") exceeds remaining Queue size (" + queue_slots_remaining + ").");
                    ExternalCall.FileQueueError(this.fileQueueError_Callback, this.ERROR_CODE_QUEUE_LIMIT_EXCEEDED, null, queue_slots_remaining.toString());
                } else {
                    // Process each selected file
                    for (var i:Number = 0; i < file_reference_list.length; i++) {
                        var file_item:FileItem = new FileItem(file_reference_list[i], this.movieName, this.file_index.length);
                        this.file_index[file_item.index] = file_item;

                        // Verify that the file is accessible. Zero byte files and possibly other conditions can cause a file to be inaccessible.
                        var jsFileObj:Object = file_item.ToJavaScriptObject();
                        var is_valid_file_reference:Boolean = (jsFileObj.filestatus !== FileItem.FILE_STATUS_ERROR);

                        if (is_valid_file_reference) {
                            // Check the size, if it's within the limit add it to the upload list.
                            var size_result:Number = this.CheckFileSize(file_item);
                            var is_valid_filetype:Boolean = this.CheckFileType(file_item);
                            if(size_result == this.SIZE_OK && is_valid_filetype) {
                                file_item.file_status = FileItem.FILE_STATUS_QUEUED;
                                this.file_queue.push(file_item);
                                this.queued_uploads++;
                                num_files_queued++;
                                this.Debug("Event: fileQueued : File ID: " + file_item.id);
                                ExternalCall.FileQueued(this.fileQueued_Callback, file_item.ToJavaScriptObject());
                            }
                            else if (!is_valid_filetype) {
                                //file_item.file_reference = null; 	// Cleanup the object
                                file_item.file_status = FileItem.FILE_STATUS_ERROR;
                                this.queue_errors++;
                                this.Debug("Event: fileQueueError : File not of a valid type.");
                                ExternalCall.FileQueueError(this.fileQueueError_Callback, this.ERROR_CODE_INVALID_FILETYPE, file_item.ToJavaScriptObject(), "File is not an allowed file type.");
                            }
                            else if (size_result == this.SIZE_TOO_BIG) {
                                //file_item.file_reference = null; 	// Cleanup the object
                                file_item.file_status = FileItem.FILE_STATUS_ERROR;
                                this.queue_errors++;
                                this.Debug("Event: fileQueueError : File exceeds size limit.");
                                ExternalCall.FileQueueError(this.fileQueueError_Callback, this.ERROR_CODE_FILE_EXCEEDS_SIZE_LIMIT, file_item.ToJavaScriptObject(), "File size exceeds allowed limit.");
                            }
                            else if (size_result == this.SIZE_ZERO_BYTE) {
                                file_item.file_reference = null; 	// Cleanup the object
                                file_item.file_status = FileItem.FILE_STATUS_ERROR;
                                this.queue_errors++;
                                this.Debug("Event: fileQueueError : File is zero bytes.");
                                ExternalCall.FileQueueError(this.fileQueueError_Callback, this.ERROR_CODE_ZERO_BYTE_FILE, file_item.ToJavaScriptObject(), "File is zero bytes and cannot be uploaded.");
                            }
                        } else {
                            file_item.file_reference = null; 	// Cleanup the object
                            file_item.file_status = FileItem.FILE_STATUS_ERROR;
                            this.queue_errors++;
                            this.Debug("Event: fileQueueError : File is zero bytes or FileReference is invalid.");
                            ExternalCall.FileQueueError(this.fileQueueError_Callback, this.ERROR_CODE_ZERO_BYTE_FILE, file_item.ToJavaScriptObject(), "File is zero bytes or cannot be accessed and cannot be uploaded.");
                        }
                    }
                }

                this.Debug("Event: fileDialogComplete : Finished processing selected files. Files selected: " + file_reference_list.length + ". Files Queued: " + num_files_queued);
                ExternalCall.FileDialogComplete(this.fileDialogComplete_Callback, file_reference_list.length, num_files_queued, this.queued_uploads);
            }


            /* ****************************************************************
               Externally exposed functions
             ****************************************************************** */
            // Opens a file browser dialog that allows one file to be selected.
            private function SelectFile():void  {
                this.fileBrowserOne = new FileReference();
                this.fileBrowserOne.addEventListener(Event.SELECT, this.Select_One_Handler);
                this.fileBrowserOne.addEventListener(Event.CANCEL,  this.DialogCancelled_Handler);

                // Default file type settings
                var allowed_file_types:String = "*.*";
                var allowed_file_types_description:String = "All Files";

                // Get the instance settings
                if (this.fileTypes.length > 0) allowed_file_types = this.fileTypes;
                if (this.fileTypesDescription.length > 0)  allowed_file_types_description = this.fileTypesDescription;

                this.Debug("Event: fileDialogStart : Browsing files. Single Select. Allowed file types: " + allowed_file_types);
                ExternalCall.Simple(this.fileDialogStart_Callback);

                try {
                    this.fileBrowserOne.browse([new FileFilter(allowed_file_types_description, allowed_file_types)]);
                } catch (ex:Error) {
                    this.Debug("Exception: " + ex.toString());
                }
            }

            // Opens a file browser dialog that allows multiple files to be selected.
            private function SelectFiles():void {
                var allowed_file_types:String = "*.*";
                var allowed_file_types_description:String = "All Files";

                if (this.fileTypes.length > 0) allowed_file_types = this.fileTypes;
                if (this.fileTypesDescription.length > 0)  allowed_file_types_description = this.fileTypesDescription;

                this.Debug("Event: fileDialogStart : Browsing files. Multi Select. Allowed file types: " + allowed_file_types);
                ExternalCall.Simple(this.fileDialogStart_Callback);

                try {
                    this.fileBrowserMany.browse([new FileFilter(allowed_file_types_description, allowed_file_types)]);
                } catch (ex:Error) {
                    this.Debug("Exception: " + ex.toString());
                }
            }


            // Cancel the current upload and stops.  Doesn't advance the upload pointer. The current file is requeued at the beginning.
            private function StopUpload():void {
                if (this.current_file_item != null) {

                    // Cancel the upload and re-queue the FileItem
                    this.current_file_item.file_reference.cancel();

                    if (!this.useMultiPart) {
                        // Remove the event handlers
                        this.removeFileReferenceEventListeners(this.current_file_item);
                    } else {
                        this.removeURLLoaderEventListeners(this.current_file_item);
                    }

                    this.current_file_item.file_status = FileItem.FILE_STATUS_QUEUED;
                    this.file_queue.unshift(this.current_file_item);
                    var js_object:Object = this.current_file_item.ToJavaScriptObject();
                    this.current_file_item = null;

                    this.Debug("Event: uploadError: upload stopped. File ID: " + js_object.ID);
                    ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_UPLOAD_STOPPED, js_object, "Upload Stopped");
                    this.Debug("Event: uploadComplete. File ID: " + js_object.ID);
                    ExternalCall.UploadComplete(this.uploadComplete_Callback, js_object);

                    this.Debug("StopUpload(): upload stopped.");
                } else {
                    this.Debug("StopUpload(): No file is currently uploading. Nothing to do.");
                }
            }

            /* Cancels the upload specified by file_id
             * If the file is currently uploading it is cancelled and the uploadComplete
             * event gets called.
             * If the file is not currently uploading then only the uploadCancelled event is fired.
             * */
            private function CancelUpload(file_id:String, triggerErrorEvent:Boolean = true):void {
                var file_item:FileItem = null;

                // Check the current file item
                if (this.current_file_item != null && (this.current_file_item.id == file_id || !file_id)) {
                    this.current_file_item.file_reference.cancel();
                    this.current_file_item.file_status = FileItem.FILE_STATUS_CANCELLED;
                    this.upload_cancelled++;

                    if (triggerErrorEvent) {
                        this.Debug("Event: uploadError: File ID: " + this.current_file_item.id + ". Cancelled current upload");
                        ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_FILE_CANCELLED, this.current_file_item.ToJavaScriptObject(), "File Upload Cancelled.");
                    } else {
                        this.Debug("Event: cancelUpload: File ID: " + this.current_file_item.id + ". Cancelled current upload. Suppressed uploadError event.");
                    }
                    this.UploadComplete(false);

                    this.current_file_item.urlloader.close();
                    if (this.current_file_item.socket) {
                        this.current_file_item.socket.close();
                        removeSocketListeners(this.current_file_item);
                    }

                } else if (file_id) {
                    // Find the file in the queue
                    var file_index:Number = this.FindIndexInFileQueue(file_id);
                    if (file_index >= 0) {
                        // Remove the file from the queue
                        file_item = FileItem(this.file_queue[file_index]);
                        file_item.file_status = FileItem.FILE_STATUS_CANCELLED;
                        this.file_queue[file_index] = null;
                        this.queued_uploads--;
                        this.upload_cancelled++;

                        // Cancel the file (just for good measure) and make the callback

                        this.removeURLLoaderEventListeners(file_item);
                        file_item.urlloader.close();
                        file_item.urlloader = null;
                        file_item.file_reference.cancel();
                        this.removeFileReferenceEventListeners(file_item);

                        if (file_item.socket) {
                            file_item.socket.close();
                            removeSocketListeners(file_item);
                        }

                        //file_item.file_reference = null;

                        if (triggerErrorEvent) {
                            this.Debug("Event: uploadError : " + file_item.id + ". Cancelled queued upload");
                            ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_FILE_CANCELLED, file_item.ToJavaScriptObject(), "File Cancelled");
                        } else {
                            this.Debug("Event: cancelUpload: File ID: " + file_item.id + ". Cancelled current upload. Suppressed uploadError event.");
                        }

                        // Get rid of the file object
                        file_item = null;
                    }
                } else {
                    // Get the first file and cancel it
                    while (this.file_queue.length > 0 && file_item == null) {
                        // Check that File Reference is valid (if not make sure it's deleted and get the next one on the next loop)
                        file_item = FileItem(this.file_queue.shift());	// Cast back to a FileItem
                        if (typeof(file_item) == "undefined") {
                            file_item = null;
                            continue;
                        }
                    }

                    if (file_item != null) {
                        file_item.file_status = FileItem.FILE_STATUS_CANCELLED;
                        this.queued_uploads--;
                        this.upload_cancelled++;


                        // Cancel the file (just for good measure) and make the callback
                        file_item.file_reference.cancel();

                        if (!this.useMultiPart) {
                            this.removeFileReferenceEventListeners(file_item);
                        } else {
                            file_item.urlloader.close();
                            this.removeURLLoaderEventListeners(file_item);
                        }
                        //file_item.file_reference = null;

                        if (file_item.socket) {
                            file_item.socket.close();
                            removeSocketListeners(file_item);
                        }

                        if (triggerErrorEvent) {
                            this.Debug("Event: uploadError : " + file_item.id + ". Cancelled queued upload");
                            ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_FILE_CANCELLED, file_item.ToJavaScriptObject(), "File Cancelled");
                        } else {
                            this.Debug("Event: cancelUpload: File ID: " + file_item.id + ". Cancelled current upload. Suppressed uploadError event.");
                        }

                        // Get rid of the file object
                        file_item = null;
                    }

                }

            }

            /* Requeues the indicated file. Returns true if successful or if the file is
             * already in the queue. Otherwise returns false.
             * */
            private function RequeueUpload(fileIdentifier:*):Boolean {
                var file:FileItem = null;
                if (typeof(fileIdentifier) === "number") {
                    var fileIndex:Number = Number(fileIdentifier);
                    if (fileIndex >= 0 && fileIndex < this.file_index.length) {
                        file = this.file_index[fileIndex];					
                    }
                } else if (typeof(fileIdentifier) === "string") {
                    file = FindFileInFileIndex(String(fileIdentifier));
                } else {
                    return false;
                }

                if (file !== null && file.file_reference !== null) {
                    if (file.file_status === FileItem.FILE_STATUS_IN_PROGRESS || file.file_status === FileItem.FILE_STATUS_NEW) {
                        return false;
                    } else if (file.file_status !== FileItem.FILE_STATUS_QUEUED) {
                        file.file_status = FileItem.FILE_STATUS_QUEUED;
                        this.file_queue.unshift(file);
                        this.queued_uploads++;
                    }
                    return true;
                } else {
                    return false;
                }
            }


            private function GetStats():Object {
                return {
in_progress : this.current_file_item == null ? 0 : 1,
            files_queued : this.queued_uploads,
            successful_uploads : this.successful_uploads,
            upload_errors : this.upload_errors,
            upload_cancelled : this.upload_cancelled,
            queue_errors : this.queue_errors
                };
            }
            private function SetStats(stats:Object):void {
                this.successful_uploads = typeof(stats["successful_uploads"]) === "number" ? stats["successful_uploads"] : this.successful_uploads;
                this.upload_errors = typeof(stats["upload_errors"]) === "number" ? stats["upload_errors"] : this.upload_errors;
                this.upload_cancelled = typeof(stats["upload_cancelled"]) === "number" ? stats["upload_cancelled"] : this.upload_cancelled;
                this.queue_errors = typeof(stats["queue_errors"]) === "number" ? stats["queue_errors"] : this.queue_errors;
            }

            private function GetFile(file_id:String):Object {
                var file_index:Number = this.FindIndexInFileQueue(file_id);
                if (file_index >= 0) {
                    var file:FileItem = this.file_queue[file_index];
                } else {
                    if (this.current_file_item != null) {
                        file = this.current_file_item;
                    } else {
                        for (var i:Number = 0; i < this.file_queue.length; i++) {
                            file = this.file_queue[i];
                            if (file != null) break;
                        }
                    }
                }

                if (file == null) {
                    return null;
                } else {
                    return file.ToJavaScriptObject();
                }

            }

            private function GetFileByIndex(index:Number):Object {
                if (index < 0 || index > this.file_index.length - 1) {
                    return null;
                } else {
                    return this.file_index[index].ToJavaScriptObject();
                }
            }

            private function AddFileParam(file_id:String, name:String, value:String):Boolean {
                var item:FileItem = this.FindFileInFileIndex(file_id);
                if (item != null) {
                    item.AddParam(name, value);
                    return true;
                }
                else {
                    return false;
                }
            }
            private function RemoveFileParam(file_id:String, name:String):Boolean {
                var item:FileItem = this.FindFileInFileIndex(file_id);
                if (item != null) {
                    item.RemoveParam(name);
                    return true;
                }
                else {
                    return false;
                }
            }

            private function SetUploadURL(url:String):void {
                if (typeof(url) !== "undefined" && url !== "") {
                    this.uploadURL = url;
                }
            }

            private function SetPostParams(post_object:Object):void {
                if (typeof(post_object) !== "undefined" && post_object !== null) {
                    this.uploadPostObject = post_object;
                }
            }

            private function SetFileTypes(types:String, description:String):void {
                this.fileTypes = types;
                this.fileTypesDescription = description;

                this.LoadFileExensions(this.fileTypes);
            }

            // Sets the file size limit.  Accepts size values with units: 100 b, 1KB, 23Mb, 4 Gb
            // Parsing is not robust. "100 200 MB KB B GB" parses as "100 MB"
            private function SetFileSizeLimit(size:String):void {
                var value:Number = 0;
                var unit:String = "kb";

                // Trim the string
                var trimPattern:RegExp = /^\s*|\s*$/;

                size = size.toLowerCase();
                size = size.replace(trimPattern, "");


                // Get the value part
                var values:Array = size.match(/^\d+/);
                if (values !== null && values.length > 0) {
                    value = parseInt(values[0]);
                }
                if (isNaN(value) || value < 0) value = 0;

                // Get the units part
                var units:Array = size.match(/(b|kb|mb|gb)/);
                if (units != null && units.length > 0) {
                    unit = units[0];
                }

                // Set the multiplier for converting the unit to bytes
                var multiplier:Number = 1024;
                if (unit === "b")
                    multiplier = 1;
                else if (unit === "mb")
                    multiplier = 1048576;
                else if (unit === "gb")
                    multiplier = 1073741824;

                this.fileSizeLimit = value * multiplier;
            }

            private function SetFileUploadLimit(file_upload_limit:Number):void {
                if (file_upload_limit < 0) file_upload_limit = 0;
                this.fileUploadLimit = file_upload_limit;
            }

            private function SetFileQueueLimit(file_queue_limit:Number):void {
                if (file_queue_limit < 0) file_queue_limit = 0;
                this.fileQueueLimit = file_queue_limit;
            }

            private function SetFilePostName(file_post_name:String):void {
                if (file_post_name != "") {
                    this.filePostName = file_post_name;
                }
            }

            private function SetUseQueryString(use_query_string:Boolean):void {
                this.useQueryString = use_query_string;
            }

            private function SetRequeueOnError(requeue_on_error:Boolean):void {
                this.requeueOnError = requeue_on_error;
            }

            private function SetHTTPSuccess(http_status_codes:*):void {
                this.httpSuccess = [];

                if (typeof http_status_codes === "string") {
                    var status_code_strings:Array = http_status_codes.replace(" ", "").split(",");
                    for each (var http_status_string:String in status_code_strings) 
                    {
                        try {
                            this.httpSuccess.push(Number(http_status_string));
                        } catch (ex:Object) {
                            // Ignore errors
                            this.Debug("Could not add HTTP Success code: " + http_status_string);
                        }
                    }
                }
                else if (typeof http_status_codes === "object" && typeof http_status_codes.length === "number") {
                    for each (var http_status:* in http_status_codes) 
                    {
                        try {
                            this.Debug("adding: " + http_status);
                            this.httpSuccess.push(Number(http_status));
                        } catch (ex:Object) {
                            this.Debug("Could not add HTTP Success code: " + http_status);
                        }
                    }
                }
            }

            private function SetAssumeSuccessTimeout(timeout_seconds:Number):void {
                this.assumeSuccessTimeout = timeout_seconds < 0 ? 0 : timeout_seconds;
            }		

            private function SetDebugEnabled(debug_enabled:Boolean):void {
                this.debugEnabled = debug_enabled;
            }

            /* *************************************************************
               Button Handling Functions
             *************************************************************** */
            private function SetButtonImageURL(button_image_url:String):void {
                this.buttonImageURL = button_image_url;

                try {
                    if (this.buttonImageURL !== null && this.buttonImageURL !== "") {
                        this.buttonLoader.load(new URLRequest(this.buttonImageURL));
                    }
                } catch (ex:Object) {
                }
            }

            private function ButtonClickHandler(e:MouseEvent):void {
                if (!this.buttonStateDisabled) {
                    if (this.buttonAction === this.BUTTON_ACTION_SELECT_FILE) {
                        this.SelectFile();
                    }
                    else if (this.buttonAction === this.BUTTON_ACTION_START_UPLOAD) {
                        this.StartUpload();
                    }
                    else if (this.buttonAction === this.BUTTON_ACTION_JAVASCRIPT) {
                        ExternalCall.Simple(this.buttonAction_Callback);
                    }
                    else {
                        this.SelectFiles();
                    }
                }
            }

            private function UpdateButtonState():void {
                var xOffset:Number = 0;
                var yOffset:Number = 0;

                this.buttonLoader.x = xOffset;
                this.buttonLoader.y = yOffset;

                if (this.buttonStateDisabled) {
                    this.buttonLoader.y = this.buttonHeight * -3 + yOffset;
                }
                else if (this.buttonStateMouseDown) {
                    this.buttonLoader.y = this.buttonHeight * -2 + yOffset;
                }
                else if (this.buttonStateOver) {
                    this.buttonLoader.y = this.buttonHeight * -1 + yOffset;
                }
                else {
                    this.buttonLoader.y = -yOffset;
                }
            };

            private function SetButtonDimensions(width:Number = -1, height:Number = -1):void {
                if (width >= 0) {
                    this.buttonWidth = width;
                }
                if (height >= 0) {
                    this.buttonHeight = height;
                }

                this.buttonTextField.width = this.buttonWidth;
                this.buttonTextField.height = this.buttonHeight;
                this.buttonCursorSprite.width = this.buttonWidth;
                this.buttonCursorSprite.height = this.buttonHeight;

                this.UpdateButtonState();
            }

            private function SetButtonText(button_text:String):void {
                this.buttonText = button_text;

                this.SetButtonTextStyle(this.buttonTextStyle);
            }

            private function SetButtonTextStyle(button_text_style:String):void {
                this.buttonTextStyle = button_text_style;

                var style:StyleSheet = new StyleSheet();
                style.parseCSS(this.buttonTextStyle);
                this.buttonTextField.styleSheet = style;
                this.buttonTextField.htmlText = '<span class="button-text">' + this.buttonText + '</span>';
            }

            private function SetButtonTextPadding(left:Number, top:Number):void {
                this.buttonTextField.x = this.buttonTextLeftPadding = left;
                this.buttonTextField.y = this.buttonTextTopPadding = top;
            }

            private function SetButtonDisabled(disabled:Boolean):void {
                this.buttonStateDisabled = disabled;
                this.UpdateButtonState();
            }

            private function SetButtonAction(button_action:Number):void {
                this.buttonAction = button_action;
            }

            private function SetButtonCursor(button_cursor:Number):void {
                this.buttonCursor = button_cursor;

                this.buttonCursorSprite.useHandCursor = (button_cursor === this.BUTTON_CURSOR_HAND);
            }

            /* *************************************************************
               File processing and handling functions
             *************************************************************** */
            private function StartUpload(file_id:String = ""):void {
                // Only upload a file uploads are being processed.
                if (this.current_file_item != null) {
                    this.Debug("StartUpload(): Upload already in progress. Not starting another upload.");
                    return;
                }

                this.Debug("StartUpload: " + (file_id ? "File ID: " + file_id : "First file in queue"));

                // Check the upload limit
                if (this.successful_uploads >= this.fileUploadLimit && this.fileUploadLimit != 0) {
                    this.Debug("Event: uploadError : Upload limit reached. No more files can be uploaded.");
                    ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_UPLOAD_LIMIT_EXCEEDED, null, "The upload limit has been reached.");
                    this.current_file_item = null;
                    return;
                }

                // Get the next file to upload
                if (!file_id) {
                    while (this.file_queue.length > 0 && this.current_file_item == null) {
                        this.current_file_item = FileItem(this.file_queue.shift());
                        if (typeof(this.current_file_item) == "undefined") {
                            this.current_file_item = null;
                        }
                    }
                } else {
                    var file_index:Number = this.FindIndexInFileQueue(file_id);
                    if (file_index >= 0) {
                        // Set the file as the current upload and remove it from the queue
                        this.current_file_item = FileItem(this.file_queue[file_index]);
                        this.file_queue[file_index] = null;
                    } else {
                        this.Debug("Event: uploadError : File ID not found in queue: " + file_id);
                        ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_SPECIFIED_FILE_ID_NOT_FOUND, null, "File ID not found in the queue.");
                    }
                }


                if (this.current_file_item != null) {
                    // Trigger the uploadStart event which will call ReturnUploadStart to begin the actual upload
                    this.Debug("Event: uploadStart : File ID: " + this.current_file_item.id);

                    this.current_file_item.file_status = FileItem.FILE_STATUS_IN_PROGRESS;
                    ExternalCall.UploadStart(this.uploadStart_Callback, this.current_file_item.ToJavaScriptObject());
                }
                // Otherwise we've would have looped through all the FileItems. This means the queue is empty)
                else {
                    this.Debug("StartUpload(): No files found in the queue.");
                }
            }

            // This starts the upload when the user returns TRUE from the uploadStart event.  Rather than just have the value returned from
            // the function we do a return function call so we can use the setTimeout work-around for Flash/JS circular calls.
            private function ReturnUploadStart(start_upload:Boolean):void {
                if (this.current_file_item == null) {
                    this.Debug("ReturnUploadStart called but no file was prepped for uploading. The file may have been cancelled or stopped.");
                    return;
                }

                var js_object:Object;

                if (start_upload) {
                    try {
                        // Set the event handlers
                        if (!this.useMultiPart) {
                            this.current_file_item.file_reference.addEventListener(Event.OPEN, this.Open_Handler);
                            this.current_file_item.file_reference.addEventListener(ProgressEvent.PROGRESS, this.FileProgress_Handler);
                            this.current_file_item.file_reference.addEventListener(IOErrorEvent.IO_ERROR, this.IOError_Handler);
                            this.current_file_item.file_reference.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.SecurityError_Handler);
                            this.current_file_item.file_reference.addEventListener(HTTPStatusEvent.HTTP_STATUS, this.HTTPError_Handler);
                            this.current_file_item.file_reference.addEventListener(Event.COMPLETE, this.Complete_Handler);
                            this.current_file_item.file_reference.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, this.ServerData_Handler);
                        }

                        // Get the request (post values, etc)
                        var request:URLRequest = this.BuildRequest();
                        if (this.uploadURL.length == 0) {
                            this.Debug("Event: uploadError : IO Error : File ID: " + this.current_file_item.id + ". Upload URL string is empty.");

                            // Remove the event handlers
                            this.removeFileReferenceEventListeners(this.current_file_item);

                            this.current_file_item.file_status = FileItem.FILE_STATUS_QUEUED;
                            this.file_queue.unshift(this.current_file_item);
                            js_object = this.current_file_item.ToJavaScriptObject();
                            this.current_file_item = null;

                            ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_MISSING_UPLOAD_URL, js_object, "Upload URL string is empty.");
                        } else {
                            this.Debug("ReturnUploadStart(): File accepted by startUpload event and readied for upload.  Starting upload to " + request.url + " for File ID: " + this.current_file_item.id);
                            this.current_file_item.file_status = FileItem.FILE_STATUS_IN_PROGRESS;
                            if (!this.useMultiPart) {
                                this.current_file_item.file_reference.upload(request, this.filePostName, false);
                            } else {
                                this.multiPartUpload(this.current_file_item);
                            }
                        }
                    } catch (ex:Error) {
                        this.Debug("ReturnUploadStart: Exception occurred: " + message);

                        this.upload_errors++;
                        this.current_file_item.file_status = FileItem.FILE_STATUS_ERROR;

                        var message:String = ex.errorID + "\n" + ex.name + "\n" + ex.message + "\n" + ex.getStackTrace();
                        this.Debug("Event: uploadError(): Upload Failed. Exception occurred: " + message);
                        ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_UPLOAD_FAILED, this.current_file_item.ToJavaScriptObject(), message);

                        this.UploadComplete(true);
                    }
                } else {
                    if (!this.useMultiPart) {
                        // Remove the event handlers
                        this.removeFileReferenceEventListeners(this.current_file_item);
                    } else {
                        this.removeURLLoaderEventListeners(this.current_file_item);
                    }

                    // Re-queue the FileItem
                    this.current_file_item.file_status = FileItem.FILE_STATUS_QUEUED;
                    js_object = this.current_file_item.ToJavaScriptObject();
                    this.file_queue.unshift(this.current_file_item);
                    this.current_file_item = null;

                    this.Debug("Event: uploadError : Call to uploadStart returned false. Not uploading the file.");
                    ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_FILE_VALIDATION_FAILED, js_object, "Call to uploadStart return false. Not uploading file.");
                    this.Debug("Event: uploadComplete : Call to uploadStart returned false. Not uploading the file.");
                    ExternalCall.UploadComplete(this.uploadComplete_Callback, js_object);
                }
            }

            // Completes the file upload by deleting it's reference, advancing the pointer.
            // Once this event fires a new upload can be started.
            private function UploadComplete(eligible_for_requeue:Boolean):void {
                var jsFileObj:Object = this.current_file_item.ToJavaScriptObject();

                this.removeFileReferenceEventListeners(this.current_file_item);
                this.removeURLLoaderEventListeners(this.current_file_item);

                if (!eligible_for_requeue || this.requeueOnError == false) {
                    //this.current_file_item.file_reference = null;
                    this.queued_uploads--;
                } else if (this.requeueOnError == true) {
                    this.current_file_item.file_status = FileItem.FILE_STATUS_QUEUED;
                    this.file_queue.unshift(this.current_file_item);
                }

                this.current_file_item = null;

                this.Debug("Event: uploadComplete : Upload cycle complete.");
                ExternalCall.UploadComplete(this.uploadComplete_Callback, jsFileObj);
            }


            /* *************************************************************
               Utility Functions
             *************************************************************** */


            // Check the size of the file against the allowed file size. If it is less the return TRUE. If it is too large return FALSE
            private function CheckFileSize(file_item:FileItem):Number {
                if (file_item.file_reference.size == 0) {
                    return this.SIZE_ZERO_BYTE;
                } else if (this.fileSizeLimit != 0 && file_item.file_reference.size > this.fileSizeLimit) {
                    return this.SIZE_TOO_BIG;
                } else {
                    return this.SIZE_OK;
                }
            }

            private function CheckFileType(file_item:FileItem):Boolean {
                // If no extensions are defined then a *.* was passed and the check is unnecessary
                if (this.valid_file_extensions.length == 0) {
                    return true;
                }

                var fileRef:FileReference = file_item.file_reference;
                var last_dot_index:Number = fileRef.name.lastIndexOf(".");
                var extension:String = "";
                if (last_dot_index >= 0) {
                    extension = fileRef.name.substr(last_dot_index + 1).toLowerCase();
                }

                var is_valid_filetype:Boolean = false;
                for (var i:Number=0; i < this.valid_file_extensions.length; i++) {
                    if (String(this.valid_file_extensions[i]) == extension) {
                        is_valid_filetype = true;
                        break;
                    }
                }

                return is_valid_filetype;
            }

            private function BuildRequest():URLRequest {
                // Create the request object
                var request:URLRequest = new URLRequest();
                request.method = URLRequestMethod.POST;

                var file_post:Object = this.current_file_item.GetPostObject();

                if (this.useQueryString) {
                    var pairs:Array = new Array();
                    for (key in this.uploadPostObject) {
                        this.Debug("Global URL Item: " + key + "=" + this.uploadPostObject[key]);
                        if (this.uploadPostObject.hasOwnProperty(key)) {
                            pairs.push(escape(key) + "=" + escape(this.uploadPostObject[key]));
                        }
                    }

                    for (key in file_post) {
                        this.Debug("File Post Item: " + key + "=" + file_post[key]);
                        if (file_post.hasOwnProperty(key)) {
                            pairs.push(escape(key) + "=" + escape(file_post[key]));
                        }
                    }

                    request.url = this.uploadURL  + (this.uploadURL.indexOf("?") > -1 ? "&" : "?") + pairs.join("&");

                } else {
                    var key:String;
                    var post:URLVariables = new URLVariables();
                    for (key in this.uploadPostObject) {
                        this.Debug("Global Post Item: " + key + "=" + this.uploadPostObject[key]);
                        if (this.uploadPostObject.hasOwnProperty(key)) {
                            post[key] = this.uploadPostObject[key];
                        }
                    }

                    for (key in file_post) {
                        this.Debug("File Post Item: " + key + "=" + file_post[key]);
                        if (file_post.hasOwnProperty(key)) {
                            post[key] = file_post[key];
                        }
                    }

                    request.url = this.uploadURL;
                    request.data = post;
                }

                return request;
            }

            private function Debug(msg:String):void {
                try {
                    if (this.debugEnabled) {
                        var lines:Array = msg.split("\n");
                        for (var i:Number=0; i < lines.length; i++) {
                            lines[i] = "SWF DEBUG: " + lines[i];
                        }
                        ExternalCall.Debug(this.debug_Callback, lines.join("\n"));
                    }
                } catch (ex:Error) {
                    // pretend nothing happened
                    trace(ex);
                }
            }

            private function PrintDebugInfo():void {
                var key: String;
                var debug_info:String = "\n----- SWF DEBUG OUTPUT ----\n";
                debug_info += "Build Number:           " + this.build_number + "\n";
                debug_info += "movieName:              " + this.movieName + "\n";
                debug_info += "Upload URL:             " + this.uploadURL + "\n";
                debug_info += "File Types String:      " + this.fileTypes + "\n";
                debug_info += "Parsed File Types:      " + this.valid_file_extensions.toString() + "\n";
                debug_info += "HTTP Success:           " + this.httpSuccess.join(", ") + "\n";
                debug_info += "File Types Description: " + this.fileTypesDescription + "\n";
                debug_info += "File Size Limit:        " + this.fileSizeLimit + " bytes\n";
                debug_info += "File Upload Limit:      " + this.fileUploadLimit + "\n";
                debug_info += "File Queue Limit:       " + this.fileQueueLimit + "\n";
                debug_info += "Use Chunk:              " + this.useChunk + "\n";
                debug_info += "Use MultiPart:          " + this.useMultiPart + "\n";
                debug_info += "Chunk Size:             " + this.chunkSize + "\n";
                debug_info += "Use Socket:             " + this.useSocket + "\n";
                debug_info += "Headers:\n";
                for (key in this.headers) {
                    if (this.headers.hasOwnProperty(key)) {
                        debug_info += "                        " + key + "=" + this.headers[key] + "\n";
                    }
                }
                debug_info += "Post Params:\n";
                for (key in this.uploadPostObject) {
                    if (this.uploadPostObject.hasOwnProperty(key)) {
                        debug_info += "                        " + key + "=" + this.uploadPostObject[key] + "\n";
                    }
                }
                debug_info += "----- END SWF DEBUG OUTPUT ----\n";

                this.Debug(debug_info);
            }

            private function FindIndexInFileQueue(file_id:String):Number {
                for (var i:Number = 0; i < this.file_queue.length; i++) {
                    var item:FileItem = this.file_queue[i];
                    if (item != null && item.id == file_id) return i;
                }

                return -1;
            }

            private function FindFileInFileIndex(file_id:String):FileItem {
                for (var i:Number = 0; i < this.file_index.length; i++) {
                    var item:FileItem = this.file_index[i];
                    if (item != null && item.id == file_id) return item;
                }

                return null;
            }


            // Parse the file extensions in to an array so we can validate them agains
            // the files selected later.
            private function LoadFileExensions(filetypes:String):void {
                var extensions:Array = filetypes.split(";");
                this.valid_file_extensions = new Array();

                for (var i:Number=0; i < extensions.length; i++) {
                    var extension:String = String(extensions[i]);
                    var dot_index:Number = extension.lastIndexOf(".");

                    if (dot_index >= 0) {
                        extension = extension.substr(dot_index + 1).toLowerCase();
                    } else {
                        extension = extension.toLowerCase();
                    }

                    // If one of the extensions is * then we allow all files
                    if (extension == "*") {
                        this.valid_file_extensions = new Array();
                        break;
                    }

                    this.valid_file_extensions.push(extension);
                }
            }

            private function parseSubSet(subset_string:String):Object {
                var robject:Object = {};

                if (subset_string != null) {
                    var name_value_pairs:Array = subset_string.split("&amp;");

                    for (var i:Number = 0; i < name_value_pairs.length; i++) {
                        var name_value:String = String(name_value_pairs[i]);
                        var index_of_equals:Number = name_value.indexOf("=");
                        if (index_of_equals > 0) {
                            robject[decodeURIComponent(name_value.substring(0, index_of_equals))] = decodeURIComponent(name_value.substr(index_of_equals + 1));
                        }
                    }
                }
                return robject;
            }

            private function loadPostParams(param_string: String): void {
                this.uploadPostObject = this.parseSubSet(param_string);
            }

            private function loadHeaders(header_string: String): void {
                this.headers = this.parseSubSet(header_string);
            }

            private function removeFileReferenceEventListeners(file_item:FileItem):void {
                if (file_item != null && file_item.file_reference != null) {
                    file_item.file_reference.removeEventListener(Event.OPEN, this.Open_Handler);
                    file_item.file_reference.removeEventListener(ProgressEvent.PROGRESS, this.FileProgress_Handler);
                    file_item.file_reference.removeEventListener(IOErrorEvent.IO_ERROR, this.IOError_Handler);
                    file_item.file_reference.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, this.SecurityError_Handler);
                    file_item.file_reference.removeEventListener(HTTPStatusEvent.HTTP_STATUS, this.HTTPError_Handler);
                    file_item.file_reference.removeEventListener(DataEvent.UPLOAD_COMPLETE_DATA, this.ServerData_Handler);
                }
            }

            /**************************************************************
             *
             * MultiPart Upload
             *
             ***************************************************************/


            private function multiPartUpload(file_item: FileItem): void {
                removeFileReferenceEventListeners(file_item);
                removeURLLoaderEventListeners(file_item);
                file_item.file_reference.addEventListener(Event.COMPLETE, fileLoadComplete_Handler);
                file_item.file_reference.load();
            }

            private function fileLoadComplete_Handler(event: Event): void {
                var file_item: FileItem = current_file_item;
                event.currentTarget.removeEventListener(Event.COMPLETE, arguments.callee);
                fileLoadComplete(event,file_item);
            }

            private function fileLoadComplete(event: Event,file_item: FileItem): void {

                if (this.useChunk) {

                    file_item.chunks = Math.ceil(file_item.file_reference.size / this.chunkSize);
                    if (file_item.chunks < 4 && file_item.file_reference.size > 1024*32) {
                        this.chunkSize = Math.ceil(file_item.file_reference.size/4);
                        file_item.chunks = 4;
                    }   
                    file_item.chunk = 0;
                } else {
                    this.chunkSize = file_item.file_reference.size;
                    file_item.chunks = 1;
                    file_item.chunk = 0;
                }   
                this.uploadNextChunk(file_item);
            }

            private function chunkComplete(event: Event,file_item: FileItem): void {
                var bytesLoaded:Number = file_item.chunk * this.chunkSize + file_item.chunkData.length;
                var bytesTotal:Number = file_item.file_reference.size;
                ExternalCall.UploadProgress(this.uploadProgress_Callback, file_item.ToJavaScriptObject(), bytesLoaded, bytesTotal);

                file_item.chunk++;
                file_item.chunkData.clear();
                removeURLLoaderEventListeners(file_item);
                
                if (file_item.chunk < file_item.chunks) {
                    file_item.urlloader.close();
                    this.uploadNextChunk(file_item);
                }
                else {
                    if (file_item.file_reference.data) {
                        file_item.file_reference.data.clear();
                    }
                    file_item.chunks = 0;
                    file_item.chunk = 0;
                    this.UploadSuccess(file_item, file_item.urlloader.data);
                }
            }

            private function uploadNextChunk(file_item: FileItem): Boolean {
                if (!useSocket) {
                    this.Debug("uploadNextChunk(): uploadNextChunk for File ID: " + this.current_file_item.id + " chunk " + file_item.chunk.toString() + " of " + file_item.chunks.toString());
                    file_item.chunkData = new ByteArray();

                    file_item.file_reference.data.readBytes(file_item.chunkData,0, file_item.file_reference.data.position + this.chunkSize > file_item.file_reference.data.length ? file_item.file_reference.data.length - file_item.file_reference.data.position: this.chunkSize);  
                    file_item.urlloader = new URLLoader();
                    file_item.urlloader.addEventListener(Event.COMPLETE, chunkComplete_Handler);
                    file_item.urlloader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, MultiPart_Security);
                    file_item.urlloader.addEventListener(Event.OPEN, MultiPart_Open);
                    file_item.urlloader.addEventListener(HTTPStatusEvent.HTTP_STATUS, MultiPart_HTTPStatus);

                    var req: URLRequest = new URLRequest(this.uploadURL);
                    //var cookie: String = ExternalInterface.call("function() { return document.cookie.toString() }");
                    req.method = URLRequestMethod.POST;

                    var boundary: String = '----sapoboundary' + new Date().getTime(),
                        dashdash: String = '--',crlf:String = '\r\n',multipartBlob: ByteArray = new ByteArray();

                    var key: String
                    for (key in this.headers) {
                        if (this.headers.hasOwnProperty(key)) {
                            if (this.FORB_HEADER.indexOf(key.toLowerCase()) < 0 && key != "Cookie") {
                                req.requestHeaders.push(new URLRequestHeader(key,headers[key]));
                            }
                        }
                    }
                    req.requestHeaders.push(new URLRequestHeader("Content-Type",'multipart/form-data; boundary=' + boundary));

                    for (key in this.uploadPostObject) {
                        if (this.uploadPostObject.hasOwnProperty(key)) {
                            multipartBlob.writeUTFBytes(dashdash + boundary + crlf + 
                                    'Content-Disposition: form-data; name="'+key+'"' + crlf+crlf +
                                    this.uploadPostObject[key] + crlf);
                        }
                    }

                    var filePostObject: Object = file_item.GetPostObject();
                    for (key in filePostObject) {
                        if (filePostObject.hasOwnProperty(key)) {
                            multipartBlob.writeUTFBytes(dashdash + boundary + crlf + 
                                    'Content-Disposition: form-data; name="'+key+'"' + crlf+crlf +
                                    filePostObject[key] + crlf);
                        }
                    }

                    multipartBlob.writeUTFBytes(dashdash + boundary + crlf + 
                            'Content-Disposition: form-data; name="file"; filename="'+ file_item.file_reference.name+'"' + crlf + 
                            'Content-Type: ' + 'application/octet-stream' + crlf + crlf);

                    multipartBlob.writeBytes(file_item.chunkData);
                    multipartBlob.writeUTFBytes(crlf + dashdash + boundary + dashdash + crlf);

                    req.data = multipartBlob;

                    setTimeout( function(): void { file_item.urlloader.load(req);},1);
                }

                if (useSocket) {
                    createSocket();
                }

                return true;
            }

            private function removeURLLoaderEventListeners(file_item: FileItem): void {
                if (file_item != null && file_item.urlloader != null) {
                    file_item.urlloader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,MultiPart_Security);
                    file_item.urlloader.removeEventListener(Event.OPEN,MultiPart_Open);
                    file_item.urlloader.removeEventListener(HTTPStatusEvent.HTTP_STATUS,MultiPart_HTTPStatus);
                }
            }

            private function chunkComplete_Handler(event: Event): void {
                var file_item: FileItem = this.current_file_item;

                if (file_item) {
                    this.Debug("chunkComplete(): chunkComplete for File ID: " + file_item.id + " chunk " + file_item.chunk.toString() + " of " + file_item.chunks.toString());

                    event.currentTarget.removeEventListener(Event.COMPLETE, arguments.callee);
                    this.chunkComplete(event,file_item);
                } else {
                    this.Debug("chunkComplete(): file_item is null");
                }
            }

            private function MultiPart_Security(event: SecurityErrorEvent): void {
                this.SecurityError_Handler(event);
            }

            private function MultiPart_Open(event: Event): void {
                this.Open_Handler(event);
            }

            private function MultiPart_HTTPStatus(event: HTTPStatusEvent): void {
                this.HTTPError_Handler(event);
            }

            // Utils

            private function getSize(size:String):uint {
                var value:Number = 0;
                var unit:String = "kb";

                // Trim the string
                var trimPattern:RegExp = /^\s*|\s*$/;

                size = size.toLowerCase();
                size = size.replace(trimPattern, "");


                // Get the value part
                var values:Array = size.match(/^\d+/);
                if (values !== null && values.length > 0) {
                    value = parseInt(values[0]);
                }
                if (isNaN(value) || value < 0) value = 0;

                // Get the units part
                var units:Array = size.match(/(b|kb|mb|gb)/);
                if (units != null && units.length > 0) {
                    unit = units[0];
                }

                // Set the multiplier for converting the unit to bytes
                var multiplier:Number = 1024;
                if (unit === "b")
                    multiplier = 1;
                else if (unit === "mb")
                    multiplier = 1048576;
                else if (unit === "gb")
                    multiplier = 1073741824;

                return value * multiplier;
            }

            private function createSocket(): void {
                if (null == uploadURLParsed) {
                    this.Debug("ERROR: Upload URL in wrong format");
                    return;
                }
                var file_item: FileItem = this.current_file_item;
                file_item.socket = new Socket(uploadURLParsed.host, this.SOCKET_PORT);
                var socket: Socket = file_item.socket;

                socket.addEventListener(Event.CONNECT,createSocketMessage);
                socket.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS,outputProgress_Handler);
                socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,securitySocketError_Handler);
                socket.addEventListener(ProgressEvent.SOCKET_DATA,socketDataReceived_Handler);
                socket.addEventListener(Event.CLOSE, socketClosed_Handler);
                socket.addEventListener(IOErrorEvent.IO_ERROR, socketio);
                try {
                    socket.connect(uploadURLParsed.host,this.SOCKET_PORT);
                } catch(ioError:IOError) {
                    this.Debug("ERROR: IO Synchronous error");
                } catch(secError:SecurityError) {
                    this.Debug("ERROR: Security Synchronous error");
                }
            }

            private function createSocketMessage(e:Event): void {

                var localurl: Object = URLParser.parse(root.loaderInfo.url);

                var file_item: FileItem = this.current_file_item;

                var socket: Socket = file_item.socket;

                var boundary: String = '----sapoboundary' + new Date().getTime(),
                    dashdash: String = '--',
                    crlf:String = '\r\n',
                    key: String = '',
                    cookie: String = '',
                    origin: String = localurl.protocol + "://" + localurl.host + (localurl.port != "" ? ":" + localurl.port : ""),
                    referer: String = localurl.url;
                
                var formData:ByteArray = new ByteArray();
                var tailData:ByteArray = new ByteArray();
                var contentLength:uint = 0;

                try {
                    cookie = ExternalInterface.call("function() { return document.cookie.toString() }");
                } catch(e: Error) {
                    this.Debug("ERROR: Trying to get session's cookie");
                }

                socket.writeUTFBytes("POST " + uploadURLParsed.path + " HTTP/1.1" + crlf);
                socket.writeUTFBytes("Host: " + uploadURLParsed.host + crlf);
                socket.writeUTFBytes("Origin: " + origin + crlf);
                socket.writeUTFBytes("Referer: " + referer + crlf);

                if (!this.headers["Accept"]) {
                    this.headers["Accept"] = "text/html,application/xhtml-xml,application/xml;q=0.9,*/*;q=0.8";
                }

                if (!this.headers["Accept-Encoding"]) {
                    this.headers["Accept-Encoding"] = "gzip, deflate";
                }

                if (!this.headers["Connection"]) {
                    this.headers["Connection"] = "keep-alive";
                }

                if(!this.headers["Cookie"]) {
                    this.headers["Cookie"] = cookie;
                }

                socket.writeUTFBytes("User-Agent: SWFUploader" + crlf);
 
                for (key in this.headers) {
                    if (this.headers.hasOwnProperty(key)) {
                        if (this.FORB_HEADER.indexOf(key.toLowerCase()) < 0) {
                            socket.writeUTFBytes(key + ": " + headers[key] + crlf);
                        }
                    }
                }

                for (key in this.uploadPostObject) {
                    if (this.uploadPostObject.hasOwnProperty(key)) {
                        formData.writeUTFBytes(dashdash + boundary + crlf + 
                                'Content-Disposition: form-data; name="'+key+'"' + crlf+crlf +
                                this.uploadPostObject[key] + crlf);
                    }
                }

                formData.writeUTFBytes(dashdash + boundary + crlf + 'Content-Disposition: form-data; name="file"; filename="'+ file_item.file_reference.name+'"' + crlf + 'Content-Type: ' + 'application/octet-stream' + crlf + crlf);
                tailData.writeUTFBytes(crlf + dashdash + boundary + dashdash + crlf);

                contentLength = formData.length + tailData.length + file_item.file_reference.data.length;

                //this.chunkSize = 1024*1024*2;


                socket.writeUTFBytes("Content-Type: multipart/form-data; boundary=" + boundary + crlf);
                socket.writeUTFBytes("Content-Length: " + contentLength.toString() + crlf);
                socket.writeUTFBytes(crlf + crlf);

                socket.writeBytes(formData);

                file_item.file_reference.data.position = 0;
            
                while(file_item.file_reference.data.position < file_item.file_reference.data.length) {
                    
                    file_item.file_reference.data.readBytes(file_item.chunkData,0, file_item.file_reference.data.position + this.chunkSize > file_item.file_reference.data.length ? file_item.file_reference.data.length - file_item.file_reference.data.position: this.chunkSize);  
                    socket.writeBytes(file_item.chunkData);
                    socket.flush();
                    file_item.chunkData.clear();

                }
                socket.writeBytes(tailData);
                tailData.clear();
                formData.clear();

                socket.flush();
            }

            private function outputProgress_Handler(event: OutputProgressEvent): void {
                var file_item: FileItem = this.current_file_item;
                var bytesLoaded: Number = 0;
                var bytesTotal: Number = 0;

                bytesLoaded = event.bytesTotal;
                bytesTotal = file_item.file_reference.data.length;

                this.Debug("Event: uploadProgress: File ID: " + file_item.id + ". Bytes: " + bytesLoaded + ". Total: " + bytesTotal);
                ExternalCall.UploadProgress(this.uploadProgress_Callback, this.current_file_item.ToJavaScriptObject(), bytesLoaded, bytesTotal);
            }

            private function securitySocketError_Handler(event: SecurityErrorEvent): void {
                this.Debug("ERROR: Couldn't connect to " + uploadURLParsed.host + ":" + SOCKET_PORT + " because security problems");
            }

            private function socketDataReceived_Handler(event: ProgressEvent): void {
                var file_item: FileItem = this.current_file_item;
                var socket: Socket = file_item.socket;

                var result: Object = this.parseHTTPResult(socket.readUTFBytes(socket.bytesAvailable));

                socket.close();

                if (result["code"] == "200") {
                    this.successful_uploads++;
                    file_item.file_status = FileItem.FILE_STATUS_SUCCESS;

                    this.Debug("Event: uploadSuccess: File ID: " + file_item.id + " Response Received:  " + result["code"] + " Data: ");

                    ExternalCall.UploadSuccess(this.uploadSuccess_Callback, file_item.ToJavaScriptObject(), "", true);

                    this.UploadComplete(false);
                } else {
                    file_item.file_status = FileItem.FILE_STATUS_ERROR;

                    this.Debug("Event: uploadError: File ID: " + file_item.id + " Response Received: " + result["code"] + " Data: ");
                    ExternalCall.UploadError(this.uploadError_Callback, result["code"], file_item.ToJavaScriptObject(),"");

                    this.UploadComplete(true);

                }

                removeSocketListeners(file_item);
            }
            private function socketClosed_Handler(event: Event): void {
                var file_item: FileItem = this.current_file_item;
                this.Debug("Socket: Socket Closed to " + uploadURLParsed.host + ":" + SOCKET_PORT);
                removeSocketListeners(file_item);
            }
            private function socketio(e: IOErrorEvent): void {
                this.Debug("ERROR: IO Error from " + uploadURLParsed.host + ":" + SOCKET_PORT);
                this.Debug(e.toString());
            }

            private function removeSocketListeners(file_item: FileItem): void {

                if (file_item != null && file_item.socket != null) {
                    var socket: Socket = file_item.socket;

                    socket.removeEventListener(Event.CONNECT,createSocketMessage);
                    socket.removeEventListener(Event.CLOSE, socketClosed_Handler);
                    socket.removeEventListener(OutputProgressEvent.OUTPUT_PROGRESS, outputProgress_Handler);
                    socket.removeEventListener(ProgressEvent.SOCKET_DATA, socketDataReceived_Handler);
                    socket.removeEventListener(IOErrorEvent.IO_ERROR,socketio);
                    socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securitySocketError_Handler);
                }

            }

            private function parseHTTPResult(response: String): Object {
                var robject: Object = new Object();
                var code: String = "";
                var headers: Array = response.split("\n");
                var regex: RegExp = /\d{3}/;

                var result: Array = headers[0].match(regex);
                if (result.length > 0) {
                    code = result[0];
                }
                
                robject["code"] = code;

                this.Debug("HTTP Response:\n\r" + response);

                return robject;
            }

            public function htmlEscape(str:String):String {
                return XMLDocument( new XMLNode( XMLNodeType.TEXT_NODE, str ) ).toString();
            }
        }
}
