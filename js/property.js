function maso(){
 $('.main').masonry();
}

$(function(){
	maso();
	var options={
		linkTitle: 'styleswichter',
		cookieName: 'selected-style'
	};
	$.fn.StyleSwichter(options);
	
   	setTimeout("maso()",1500);

});


//以下は、ウィンドウリサイズ用、IE対策済み
var _globalLock = 0;
var _size = { w: 0, h: 0 };
var _ie = document.uniqueID;
var _quirks = (document.compatMode || "") !== "CSS1Compat";
var _ieroot = _quirks ? "body" : "documentElement";

function getInnerSize() {
  var root = _ie ? document[_ieroot] : window;
  return { w: root.innerWidth  || root.clientWidth,
           h: root.innerHeight || root.clientHeight };
}

// resize agent
function agent() {
  function loop() {
    if (!_globalLock++) {
      var size = getInnerSize();
      if (_size.w !== size.w || _size.h !== size.h) { // resized
        _size = size; // update
      $('.main').masonry(); 
      }
      setTimeout(function() { _globalLock = 0; }, 0); // delay unlock
    }
    setTimeout(loop, 100);
  }
  setTimeout(loop, 100);
}
