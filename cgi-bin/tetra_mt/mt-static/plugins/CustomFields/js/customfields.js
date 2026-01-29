var IE = document.all?true:false
var tempX = 0;
var tempY = 0;
// If NS -- that is, !IE -- then set up for mouse capture
if (!IE) document.captureEvents(Event.MOUSEMOVE)

// Set-up to use getMouseXY function onMouseMove
document.onmousemove = getMouseXY;

function getMouseXY(e) {
  if (IE) { // grab the x-y pos.s if browser is IE
    tempX = event.clientX + document.body.scrollLeft;
    tempY = event.clientY + document.documentElement.scrollTop;
    tempY += document.body.scrollTop;
  } else {  // grab the x-y pos.s if browser is NS
    tempX = e.pageX;
    tempY = e.pageY;
  }  
  // catch possible negative values in NS4
  if (tempX < 0){tempX = 0}
  if (tempY < 0){tempY = 0}  
  return true
}

function showCustomFieldDescription(d) {
	var s = document.getElementById('customfield-description');
	s.innerHTML = '<p>' + d + '</p>';
	s.style.display = 'block';
	s.style.top = tempY + 10 + 'px';
	s.style.left = tempX + 10 + 'px';
}

function hideCustomFieldDescription() {
	var s = document.getElementById('customfield-description');
	s.style.display = 'none';
}

function changeOrder(f) {
	var order = new Array();
	var p = document.getElementById('reorder-container').getElementsByTagName('p');
	for (var i = 0; i < p.length; i++) {
		order[i] = p[i].id;
	}
	f.order.value = order.join('::');
	f.submit();
}