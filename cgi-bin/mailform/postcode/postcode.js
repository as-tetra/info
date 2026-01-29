<!--
	var postcode_formname = "";
	var postcode_elementname = "";
	function checkPostcode(getFormname,getPostcode,getElementname){
		data = document.forms[getFormname].elements[getPostcode].value;
		data = data.replace("-", "");
		postcode_formname = getFormname;
		postcode_elementname = getElementname;
		if(data.length > 6){
			window.open("postcode/index.html?"+data,"postcodewindow","width=320,height=240,scrollbars=no,location=no");
		}
		else{
			alert("7Œ…‚Ì—X•Ö”Ô†‚ð“ü—Í‚µ‚Ä‰º‚³‚¢");
		}
	}
	function setPostcode(getAddress){
		document.forms[postcode_formname].elements[postcode_elementname].value = getAddress;
	}
//-->