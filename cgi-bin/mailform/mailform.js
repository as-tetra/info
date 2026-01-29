<!--
	//mailform include javascript ver5.0
	function sendMail(obj){
		var caution = "";
		var errorflag = 0;
		var must = obj.elements["must_id"].defaultValue;
		var error_element_number = new Array();
		var email_address = "";
		for(i=0;i<obj.length;i++){
			var elementType = obj.elements[i].type;
			var errortext = obj.elements[i].name.replace(must,"");
			var must_flag = obj.elements[i].name.indexOf(must,0);
			if(errortext == "email"){
				email_address = obj.elements[i].value;
				if(must_flag > -1){
					chkMail = obj.elements[i].value;
					check = /.+@.+\..+/;
					if (!chkMail.match(check)){
						obj.elements[i].style.backgroundColor='#FFEEEE';
						obj.elements[i].style.color='#FF0000';
						error_element_number.push(i);
						caution = caution + "メールアドレスが正しくありません。\n";
						errorflag = 2;
					}
					else{
						obj.elements[i].style.backgroundColor='#FFFFFF';
						obj.elements[i].style.color='#000000';
					}
				}
				else if(obj.elements[i].value != ""){
					chkMail = obj.elements[i].value;
					check = /.+@.+\..+/;
					if (!chkMail.match(check)){
						obj.elements[i].style.backgroundColor='#FFEEEE';
						obj.elements[i].style.color='#FF0000';
						error_element_number.push(i);
						caution = caution + "メールアドレスが正しくありません。\n";
						errorflag = 2;
					}
					else{
						obj.elements[i].style.backgroundColor='#FFFFFF';
						obj.elements[i].style.color='#000000';
					}
				}
			}
			else if(errortext == "confirm_email"){
				if(email_address != ""){
					if(email_address != obj.elements[i].value){
						obj.elements[i].style.backgroundColor='#FFEEEE';
						obj.elements[i].style.color='#FF0000';
						error_element_number.push(i);
						caution = caution + "確認用メールアドレスとメールアドレスが一致しません。\n";
						errorflag = 3;
					}
					else{
						obj.elements[i].style.backgroundColor='#FFFFFF';
						obj.elements[i].style.color='#000000';
					}
				}
			}
			else if(must_flag > -1){
				if(elementType == "text" || elementType == "textarea"){
					if(obj.elements[i].value == ""){
						obj.elements[i].style.backgroundColor='#FFEEEE';
						error_element_number.push(i);
						caution = caution + errortext +"が未入力です。\n";
						errorflag = 1;
					}
					else{
						obj.elements[i].style.backgroundColor='#FFFFFF';
					}
				}
				else if(elementType == "checkbox"){
					if(obj.elements[i].checked == false){
						error_element_number.push(i);
						caution = caution + errortext +"がチェックされていません。\n";
						errorflag = 1;
					}
				}
				else if(elementType == "select-multiple" || elementType == "select-one"){
					if(obj.elements[i].selectedIndex > -1){
						var selectCnt = obj.elements[i].selectedIndex;
						if(obj.elements[i].options[selectCnt].value == ""){
							error_element_number.push(i);
							caution = caution + errortext +"が選択されていません。\n";
							errorflag = 1;
						}
					}
					else{
						error_element_number.push(i);
						caution = caution + errortext +"が選択されていません。\n";
						errorflag = 1;
					}
				}
			}
		}
		
		if(errorflag == 0){
			if(confirm("送信してもよろしいですか？")){
				for(i=0;i<obj.length ;i++){
					obj.elements[i].name = obj.elements[i].name.replace(must,"");
					if(obj.elements[i].type == "submit"){
						obj.elements[i].disabled = true;
					}
				}
				obj.elements["must_id"].value = document.location;
				obj.elements["must_id"].value = obj.elements["must_id"].value.replace(location.hash,"");
				return true;
			}
			else{
				return false;
			}
		}
		else{
			caution = "TYPE "+errorflag+" ERROR\n"+caution;
			alert(caution);
			obj.elements[error_element_number[0]].focus();
			return false;
		}
	}
	
	function debug(){
		alert(document.cookie);
	}
	
	var conservationKey = "(resume)";
	function keepField(formId){
		var setValue = "";
		var obj = document.forms[formId];
		var elementsList = new Array();
		for(i=0;i<obj.length;i++){
			if(obj.elements[i].type == "checkbox" || obj.elements[i].type == "radio"){
				if(obj.elements[i].checked){
					setValue += "1" + "&";
				}
				else{
					setValue += "0" + "&";
				}
			}
			else if(obj.elements[i].type == "text" || obj.elements[i].type == "textarea"){
				setValue += escape(obj.elements[i].value) + "&";
			}
			else if(obj.elements[i].type == "select-multiple"){
				var selected_multiple = new Array();
				for(multiplect=0;multiplect<obj.elements[i].length;multiplect++){
					if(obj.elements[i].options[multiplect].selected){
						selected_multiple.push(multiplect);
					}
				}
				setValue += selected_multiple.join(",") + "&";
			}
			else if(obj.elements[i].type == "select-one"){
				setValue += obj.elements[i].selectedIndex + "&";
			}
		}
		setValue = "mailform=" + conservationKey + setValue + conservationKey + ";expires=";
		document.cookie = setValue;
	}
	function resumeField(formId){
		var obj = document.forms[formId];
		var valueList = new Array();
		var selectedLinks = new Array();
		var elcount = 0;
		if(document.cookie && document.cookie.indexOf(conservationKey) > -1){
			valueList = document.cookie.split(conservationKey);
			valueList = valueList[1].split("&");
			for(i=0;i<obj.length;i++){
				if(obj.elements[i].type == "checkbox" || obj.elements[i].type == "radio"){
					if(valueList[elcount] == 1){
						obj.elements[i].checked = true;
					}
					else{
						obj.elements[i].checked = false;
					}
					elcount++;
				}
				else if(obj.elements[i].type == "text" || obj.elements[i].type == "textarea"){
					obj.elements[i].value = unescape(valueList[elcount]);
					elcount++;
				}
				else if(obj.elements[i].type == "select-multiple"){
					var selected_multiple = new Array();
					selected_multiple = valueList[elcount].split(",");
					for(multiplect=0;multiplect<selected_multiple.length;multiplect++){
						if(selected_multiple[multiplect] != ""){
							obj.elements[i].options[selected_multiple[multiplect]].selected = true;
						}
					}
					elcount++;
				}
				else if(obj.elements[i].type == "select-one"){
					obj.elements[i].options[valueList[elcount]].selected = true;
					elcount++;
				}
			}
		}
	}
	
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
			alert("7桁の郵便番号を入力して下さい");
		}
	}
	function setPostcode(getAddress){
		document.forms[postcode_formname].elements[postcode_elementname].value = getAddress;
	}
//-->