<script language="JavaScript">
<!--
	if (navigator.browserLanguage){		// IE
		if (navigator.browserLanguage.indexOf("ja")>=0){
			lang	=	"ja";
		}
		else{
			lang	=	"e";
		}
	}
	else if (navigator.language){			// NN
		if (navigator.language.indexOf("ja")>=0){
			lang	=	"ja";
		}
		else{
			lang	=	"e";
		}
	}

	// next page
	if (lang == "ja"){
		document.write(<link rel="stylesheet" title="styleswichter" type="text/css" media="screen" href="/css/tetra_jp.css" />
);
	}
	else if(lang == "e"){
		document.write(<link rel="stylesheet" title="styleswichter" type="text/css" media="screen" href="/css/tetra_en.css" />
);
	}

//-->
</script>