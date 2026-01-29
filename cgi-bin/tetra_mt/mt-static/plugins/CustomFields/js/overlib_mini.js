//\//////////////////////////////////////////////////////////////////////////////////
//\  overLIB 3.50  --  This notice must remain untouched at all times.
//\  Copyright Erik Bosrup 1998-2001. All rights reserved.
//\  THIS IS A VERY MODIFIED VERSION. DO NOT EDIT OR PUBLISH. GET THE ORIGINAL!
var INARRAY=1,CAPARRAY=2,STICKY=3,BACKGROUND=4,NOCLOSE=5,CAPTION=6,LEFT=7,RIGHT=8,CENTER=9,OFFSETX=10,OFFSETY=11,FGCOLOR=12,BGCOLOR=13,TEXTCOLOR=14,CAPCOLOR=15,CLOSECOLOR=16,WIDTH=17,BORDER=18,STATUS=19,AUTOSTATUS=20,AUTOSTATUSCAP=21,HEIGHT=22,CLOSETEXT=23,SNAPX=24,SNAPY=25,FIXX=26,FIXY=27,FGBACKGROUND=28,BGBACKGROUND=29,PADX=30,PADY=31,FULLHTML=34,ABOVE=35,BELOW=36,CAPICON=37,TEXTFONT=38,CAPTIONFONT=39,CLOSEFONT=40,TEXTSIZE=41,CAPTIONSIZE=42,CLOSESIZE=43,FRAME=44,TIMEOUT=45,FUNCTION=46,DELAY=47,HAUTO=48,VAUTO=49,CLOSECLICK=50,CSSOFF=51,CSSSTYLE=52,CSSCLASS=53,FGCLASS=54,BGCLASS=55,TEXTFONTCLASS=56,CAPTIONFONTCLASS=57,CLOSEFONTCLASS=58,PADUNIT=59,HEIGHTUNIT=60,WIDTHUNIT=61,TEXTSIZEUNIT=62,TEXTDECORATION=63,TEXTSTYLE=64,TEXTWEIGHT=65,CAPTIONSIZEUNIT=66,CAPTIONDECORATION=67,CAPTIONSTYLE=68,CAPTIONWEIGHT=69,CLOSESIZEUNIT=70,CLOSEDECORATION=71,CLOSESTYLE=72,CLOSEWEIGHT=73;if(typeof ol_fgcolor=='undefined'){var ol_fgcolor="#F5F9FF";}
if(typeof ol_bgcolor=='undefined'){var ol_bgcolor="#26566E";}
if(typeof ol_textcolor=='undefined'){var ol_textcolor="#000000";}
if(typeof ol_capcolor=='undefined'){var ol_capcolor="#FFFFFF";}
if(typeof ol_closecolor=='undefined'){var ol_closecolor="#FFFFFF";}
if(typeof ol_textfont=='undefined'){var ol_textfont="Verdana,Arial,Helvetica";}
if(typeof ol_captionfont=='undefined'){var ol_captionfont="Verdana,Arial,Helvetica";}
if(typeof ol_closefont=='undefined'){var ol_closefont="Verdana,Arial,Helvetica";}
if(typeof ol_textsize=='undefined'){var ol_textsize="1";}
if(typeof ol_captionsize=='undefined'){var ol_captionsize="1";}
if(typeof ol_closesize=='undefined'){var ol_closesize="1";}
if(typeof ol_width=='undefined'){var ol_width="200";}
if(typeof ol_border=='undefined'){var ol_border="1";}
if(typeof ol_offsetx=='undefined'){var ol_offsetx=10;}
if(typeof ol_offsety=='undefined'){var ol_offsety=10;}
if(typeof ol_text=='undefined'){var ol_text="Default Text";}
if(typeof ol_cap=='undefined'){var ol_cap="";}
if(typeof ol_sticky=='undefined'){var ol_sticky=0;}
if(typeof ol_background=='undefined'){var ol_background="";}
if(typeof ol_close=='undefined'){var ol_close="Close";}
if(typeof ol_hpos=='undefined'){var ol_hpos=8;}
if(typeof ol_status=='undefined'){var ol_status="";}
if(typeof ol_autostatus=='undefined'){var ol_autostatus=0;}
if(typeof ol_height=='undefined'){var ol_height=-1;}
if(typeof ol_snapx=='undefined'){var ol_snapx=0;}
if(typeof ol_snapy=='undefined'){var ol_snapy=0;}
if(typeof ol_fixx=='undefined'){var ol_fixx=-1;}
if(typeof ol_fixy=='undefined'){var ol_fixy=-1;}
if(typeof ol_fgbackground=='undefined'){var ol_fgbackground="";}
if(typeof ol_bgbackground=='undefined'){var ol_bgbackground="";}
if(typeof ol_padxl=='undefined'){var ol_padxl=1;}
if(typeof ol_padxr=='undefined'){var ol_padxr=1;}
if(typeof ol_padyt=='undefined'){var ol_padyt=1;}
if(typeof ol_padyb=='undefined'){var ol_padyb=1;}
if(typeof ol_fullhtml=='undefined'){var ol_fullhtml=0;}
if(typeof ol_vpos=='undefined'){var ol_vpos=36;}
if(typeof ol_aboveheight=='undefined'){var ol_aboveheight=0;}
if(typeof ol_caption=='undefined'){var ol_capicon="";}
if(typeof ol_frame=='undefined'){var ol_frame=self;}
if(typeof ol_timeout=='undefined'){var ol_timeout=0;}
if(typeof ol_function=='undefined'){var ol_function=Function();}
if(typeof ol_delay=='undefined'){var ol_delay=0;}
if(typeof ol_hauto=='undefined'){var ol_hauto=0;}
if(typeof ol_vauto=='undefined'){var ol_vauto=0;}
if(typeof ol_closeclick=='undefined'){var ol_closeclick=0;}
if(typeof ol_css=='undefined'){var ol_css=51;}
if(typeof ol_fgclass=='undefined'){var ol_fgclass="";}
if(typeof ol_bgclass=='undefined'){var ol_bgclass="";}
if(typeof ol_textfontclass=='undefined'){var ol_textfontclass="";}
if(typeof ol_captionfontclass=='undefined'){var ol_captionfontclass="";}
if(typeof ol_closefontclass=='undefined'){var ol_closefontclass="";}
if(typeof ol_padunit=='undefined'){var ol_padunit="px";}
if(typeof ol_heightunit=='undefined'){var ol_heightunit="px";}
if(typeof ol_widthunit=='undefined'){var ol_widthunit="px";}
if(typeof ol_textsizeunit=='undefined'){var ol_textsizeunit="px";}
if(typeof ol_textdecoration=='undefined'){var ol_textdecoration="none";}
if(typeof ol_textstyle=='undefined'){var ol_textstyle="normal";}
if(typeof ol_textweight=='undefined'){var ol_textweight="normal";}
if(typeof ol_captionsizeunit=='undefined'){var ol_captionsizeunit="px";}
if(typeof ol_captiondecoration=='undefined'){var ol_captiondecoration="none";}
if(typeof ol_captionstyle=='undefined'){var ol_captionstyle="normal";}
if(typeof ol_captionweight=='undefined'){var ol_captionweight="bold";}
if(typeof ol_closesizeunit=='undefined'){var ol_closesizeunit="px";}
if(typeof ol_closedecoration=='undefined'){var ol_closedecoration="none";}
if(typeof ol_closestyle=='undefined'){var ol_closestyle="normal";}
if(typeof ol_closeweight=='undefined'){var ol_closeweight="normal";}
if(typeof ol_texts=='undefined'){var ol_texts=new Array("Text 0","Text 1");}
if(typeof ol_caps=='undefined'){var ol_caps=new Array("Caption 0","Caption 1");}
var otext="",ocap="",osticky=0,obackground="",oclose="Close",ohpos=8,ooffsetx=2,ooffsety=2,ofgcolor="",obgcolor="",otextcolor="",ocapcolor="",oclosecolor="",owidth=100,oborder=1,ostatus="",oautostatus=0,oheight=-1,osnapx=0,osnapy=0,ofixx=-1,ofixy=-1,ofgbackground="",obgbackground="",opadxl=0,opadxr=0,opadyt=0,opadyb=0,ofullhtml=0,ovpos=36,oaboveheight=0,ocapicon="",otextfont="Verdana,Arial,Helvetica",ocaptionfont="Verdana,Arial,Helvetica",oclosefont="Verdana,Arial,Helvetica",otextsize="1",ocaptionsize="1",oclosesize="1",oframe=self,otimeout=0,otimerid=0,oallowmove=0,ofunction=Function(),odelay=0,odelayid=0,ohauto=0,ovauto=0,ocloseclick=0,ocss=51,ofgclass="",obgclass="",otextfontclass="",ocaptionfontclass="",oclosefontclass="",opadunit="px",oheightunit="px",owidthunit="px",otextsizeunit="px",otextdecoration="",otextstyle="",otextweight="",ocaptionsizeunit="px",ocaptiondecoration="",ocaptionstyle="",ocaptionweight="",oclosesizeunit="px",oclosedecoration="",oclosestyle="",ocloseweight="",ox=0,oy=0,oallow=0,oshowingsticky=0,oremovecounter=0,over=null,ns4=(document.layers)? true:false,ns6=(document.getElementById)? true:false,ie4=(document.all)? true:false,ie5=false;if(ie4){if((navigator.userAgent.indexOf('MSIE 5')> 0)||(navigator.userAgent.indexOf('MSIE 6')> 0)){ie5=true;}
if(ns6){ns6=false;}}
if((ns4)||(ie4)||(ns6)){document.onmousemove=mouseMove
if(ns4)document.captureEvents(Event.MOUSEMOVE)
}else{overlib=no_overlib;nd=no_overlib;ver3fix=true;}
function no_overlib(){return ver3fix;}
function overlib(){otext=ol_text;ocap=ol_cap;osticky=ol_sticky;obackground=ol_background;oclose=ol_close;ohpos=ol_hpos;ooffsetx=ol_offsetx;ooffsety=ol_offsety;ofgcolor=ol_fgcolor;obgcolor=ol_bgcolor;otextcolor=ol_textcolor;ocapcolor=ol_capcolor;oclosecolor=ol_closecolor;owidth=ol_width;oborder=ol_border;ostatus=ol_status;oautostatus=ol_autostatus;oheight=ol_height;osnapx=ol_snapx;osnapy=ol_snapy;ofixx=ol_fixx;ofixy=ol_fixy;ofgbackground=ol_fgbackground;obgbackground=ol_bgbackground;opadxl=ol_padxl;opadxr=ol_padxr;opadyt=ol_padyt;opadyb=ol_padyb;ofullhtml=ol_fullhtml;ovpos=ol_vpos;oaboveheight=ol_aboveheight;ocapicon=ol_capicon;otextfont=ol_textfont;ocaptionfont=ol_captionfont;oclosefont=ol_closefont;otextsize=ol_textsize;ocaptionsize=ol_captionsize;oclosesize=ol_closesize;otimeout=ol_timeout;ofunction=ol_function;odelay=ol_delay;ohauto=ol_hauto;ovauto=ol_vauto;ocloseclick=ol_closeclick;ocss=ol_css;ofgclass=ol_fgclass;obgclass=ol_bgclass;otextfontclass=ol_textfontclass;ocaptionfontclass=ol_captionfontclass;oclosefontclass=ol_closefontclass;opadunit=ol_padunit;oheightunit=ol_heightunit;owidthunit=ol_widthunit;otextsizeunit=ol_textsizeunit;otextdecoration=ol_textdecoration;otextstyle=ol_textstyle;otextweight=ol_textweight;ocaptionsizeunit=ol_captionsizeunit;ocaptiondecoration=ol_captiondecoration;ocaptionstyle=ol_captionstyle;ocaptionweight=ol_captionweight;oclosesizeunit=ol_closesizeunit;oclosedecoration=ol_closedecoration;oclosestyle=ol_closestyle;ocloseweight=ol_closeweight;if((ns4)||(ie4)||(ns6)){oframe=ol_frame;if(ns4)over=oframe.document.overDiv
if(ie4)over=oframe.overDiv.style
if(ns6)over=oframe.document.getElementById("overDiv");}
var c=-1,ar=arguments;for(i=0;i<ar.length;i++){if(c<0){if(ar[i]==1){otext=ol_texts[ar[++i]];}else{otext=ar[i];}
c=0;}else{if(ar[i]==1){otext=ol_texts[ar[++i]];continue;}
if(ar[i]==2){ocap=ol_caps[ar[++i]];continue;}
if(ar[i]==3){osticky=1;continue;}
if(ar[i]==4){obackground=ar[++i];continue;}
if(ar[i]==NOCLOSE){oclose="";continue;}
if(ar[i]==6){ocap=ar[++i];continue;}
if(ar[i]==9||ar[i]==7||ar[i]==8){ohpos=ar[i];continue;}
if(ar[i]==10){ooffsetx=ar[++i];continue;}
if(ar[i]==11){ooffsety=ar[++i];continue;}
if(ar[i]==12){ofgcolor=ar[++i];continue;}
if(ar[i]==13){obgcolor=ar[++i];continue;}
if(ar[i]==14){otextcolor=ar[++i];continue;}
if(ar[i]==15){ocapcolor=ar[++i];continue;}
if(ar[i]==16){oclosecolor=ar[++i];continue;}
if(ar[i]==17){owidth=ar[++i];continue;}
if(ar[i]==18){oborder=ar[++i];continue;}
if(ar[i]==19){ostatus=ar[++i];continue;}
if(ar[i]==20){oautostatus=1;continue;}
if(ar[i]==21){oautostatus=2;continue;}
if(ar[i]==22){oheight=ar[++i];oaboveheight=ar[i];continue;}
if(ar[i]==23){oclose=ar[++i];continue;}
if(ar[i]==24){osnapx=ar[++i];continue;}
if(ar[i]==25){osnapy=ar[++i];continue;}
if(ar[i]==26){ofixx=ar[++i];continue;}
if(ar[i]==27){ofixy=ar[++i];continue;}
if(ar[i]==28){ofgbackground=ar[++i];continue;}
if(ar[i]==29){obgbackground=ar[++i];continue;}
if(ar[i]==30){opadxl=ar[++i];opadxr=ar[++i];continue;}
if(ar[i]==31){opadyt=ar[++i];opadyb=ar[++i];continue;}
if(ar[i]==34){ofullhtml=1;continue;}
if(ar[i]==36||ar[i]==35){ovpos=ar[i];continue;}
if(ar[i]==37){ocapicon=ar[++i];continue;}
if(ar[i]==38){otextfont=ar[++i];continue;}
if(ar[i]==39){ocaptionfont=ar[++i];continue;}
if(ar[i]==40){oclosefont=ar[++i];continue;}
if(ar[i]==41){otextsize=ar[++i];continue;}
if(ar[i]==42){ocaptionsize=ar[++i];continue;}
if(ar[i]==43){oclosesize=ar[++i];continue;}
if(ar[i]==44){opt_FRAME(ar[++i]);continue;}
if(ar[i]==45){otimeout=ar[++i];continue;}
if(ar[i]==46){opt_FUNCTION(ar[++i]);continue;}
if(ar[i]==47){odelay=ar[++i];continue;}
if(ar[i]==48){ohauto=(ohauto==0)? 1:0;continue;}
if(ar[i]==49){ovauto=(ovauto==0)? 1:0;continue;}
if(ar[i]==50){ocloseclick=(ocloseclick==0)? 1:0;continue;}
if(ar[i]==51){ocss=ar[i];continue;}
if(ar[i]==52){ocss=ar[i];continue;}
if(ar[i]==53){ocss=ar[i];continue;}
if(ar[i]==54){ofgclass=ar[++i];continue;}
if(ar[i]==55){obgclass=ar[++i];continue;}
if(ar[i]==56){otextfontclass=ar[++i];continue;}
if(ar[i]==57){ocaptionfontclass=ar[++i];continue;}
if(ar[i]==58){oclosefontclass=ar[++i];continue;}
if(ar[i]==59){opadunit=ar[++i];continue;}
if(ar[i]==60){oheightunit=ar[++i];continue;}
if(ar[i]==61){owidthunit=ar[++i];continue;}
if(ar[i]==62){otextsizeunit=ar[++i];continue;}
if(ar[i]==63){otextdecoration=ar[++i];continue;}
if(ar[i]==64){otextstyle=ar[++i];continue;}
if(ar[i]==65){otextweight=ar[++i];continue;}
if(ar[i]==66){ocaptionsizeunit=ar[++i];continue;}
if(ar[i]==67){ocaptiondecoration=ar[++i];continue;}
if(ar[i]==68){ocaptionstyle=ar[++i];continue;}
if(ar[i]==69){ocaptionweight=ar[++i];continue;}
if(ar[i]==70){oclosesizeunit=ar[++i];continue;}
if(ar[i]==71){oclosedecoration=ar[++i];continue;}
if(ar[i]==72){oclosestyle=ar[++i];continue;}
if(ar[i]==73){ocloseweight=ar[++i];continue;}}}
if(odelay==0){return overlib350();}else{odelayid=setTimeout("overlib350()",odelay);if(osticky){return false;}else{return true;}}}
function nd(){if(oremovecounter >=1){oshowingsticky=0};if((ns4)||(ie4)||(ns6)){if(oshowingsticky==0){oallowmove=0;if(over !=null)hideObject(over);}else{oremovecounter++;}}
return true;}
function overlib350(){var layerhtml;if(obackground !=""||ofullhtml){layerhtml=ol_content_background(otext,obackground,ofullhtml);}else{if(ofgbackground !=""&&ocss==CSSOFF){ofgbackground="BACKGROUND=\""+ofgbackground+"\"";}
if(obgbackground !=""&&ocss==CSSOFF){obgbackground="BACKGROUND=\""+obgbackground+"\"";}
if(ofgcolor !=""&&ocss==CSSOFF){ofgcolor="BGCOLOR=\""+ofgcolor+"\"";}
if(obgcolor !=""&&ocss==CSSOFF){obgcolor="BGCOLOR=\""+obgcolor+"\"";}
if(oheight>0&&ocss==51){oheight="HEIGHT="+oheight;}else{oheight="";}
if(ocap==""){layerhtml=ol_content_simple(otext);}else{if(osticky){layerhtml=ol_content_caption(otext,ocap,oclose);}else{layerhtml=ol_content_caption(otext,ocap,"");}}}
if(osticky){oshowingsticky=1;oremovecounter=0;}
layerWrite(layerhtml);if(oautostatus>0){ostatus=otext;if(oautostatus>1){ostatus=ocap;}}
oallowmove=0;if(otimeout>0){if(otimerid>0)clearTimeout(otimerid);otimerid=setTimeout("cClick()",otimeout);}
disp(ostatus);if(osticky){oallowmove=0;return false;}else{return true;}}
function ol_content_simple(text){if(ocss==CSSCLASS)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING="+oborder+" CELLSPACING=0 class=\""+obgclass+"\"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 class=\""+ofgclass+"\"><TR><TD VALIGN=TOP><FONT class=\""+otextfontclass+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";if(ocss==CSSSTYLE)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING="+oborder+" CELLSPACING=0 style=\"background-color: "+obgcolor+";height: "+oheight+oheightunit+";\"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 style=\"color: "+ofgcolor+";background-color: "+ofgcolor+";height: "+oheight+oheightunit+";\"><TR><TD VALIGN=TOP><FONT style=\"font-family: "+otextfont+";color: "+otextcolor+";font-size: "+otextsize+otextsizeunit+";text-decoration: "+otextdecoration+";font-weight: "+otextweight+";font-style:"+otextstyle+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";if(ocss==CSSOFF)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING="+oborder+" CELLSPACING=0 "+obgcolor+" "+oheight+"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 "+ofgcolor+" "+ofgbackground+" "+oheight+"><TR><TD VALIGN=TOP><FONT FACE=\""+otextfont+"\" COLOR=\""+otextcolor+"\" SIZE=\""+otextsize+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";set_background("");return txt;}
function ol_content_caption(text,title,close){closing="";closeevent="onMouseOver";if(ocloseclick==1)closeevent="onClick";if(ocapicon !="")ocapicon="<IMG SRC=\""+ocapicon+"\"> ";if(close !=""){if(ocss==CSSCLASS)closing="<TD ALIGN=RIGHT><A HREF=\"/\" "+closeevent+"=\"return cClick();\" class=\""+oclosefontclass+"\">"+close+"</A></TD>";if(ocss==CSSSTYLE)closing="<TD ALIGN=RIGHT><A HREF=\"/\" "+closeevent+"=\"return cClick();\" style=\"color: "+oclosecolor+";font-family: "+oclosefont+";font-size: "+oclosesize+oclosesizeunit+";text-decoration: "+oclosedecoration+";font-weight: "+ocloseweight+";font-style:"+oclosestyle+";\">"+close+"</A></TD>";if(ocss==CSSOFF)closing="<TD ALIGN=RIGHT><A HREF=\"/\" "+closeevent+"=\"return cClick();\"><FONT COLOR=\""+oclosecolor+"\" FACE=\""+oclosefont+"\" SIZE=\""+oclosesize+"\">"+close+"</FONT></A></TD>";}
if(ocss==CSSCLASS)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING="+oborder+" CELLSPACING=0 class=\""+obgclass+"\"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=0 CELLSPACING=0><TR><TD><FONT class=\""+ocaptionfontclass+"\">"+ocapicon+title+"</FONT></TD>"+closing+"</TR></TABLE><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 class=\""+ofgclass+"\"><TR><TD VALIGN=TOP><FONT class=\""+otextfontclass+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";if(ocss==CSSSTYLE)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING="+oborder+" CELLSPACING=0 style=\"background-color: "+obgcolor+";background-image: url("+obgbackground+");height: "+oheight+oheightunit+";\"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=0 CELLSPACING=0><TR><TD><FONT style=\"font-family: "+ocaptionfont+";color: "+ocapcolor+";font-size: "+ocaptionsize+ocaptionsizeunit+";font-weight: "+ocaptionweight+";font-style: "+ocaptionstyle+";\">"+ocapicon+title+"</FONT></TD>"+closing+"</TR></TABLE><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 style=\"color: "+ofgcolor+";background-color: "+ofgcolor+";height: "+oheight+oheightunit+";\"><TR><TD VALIGN=TOP><FONT style=\"font-family: "+otextfont+";color: "+otextcolor+";font-size: "+otextsize+otextsizeunit+";text-decoration: "+otextdecoration+";font-weight: "+otextweight+";font-style:"+otextstyle+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";if(ocss==CSSOFF)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING="+oborder+" CELLSPACING=0 "+obgcolor+" "+obgbackground+" "+oheight+"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=0 CELLSPACING=0><TR><TD><B><FONT COLOR=\""+ocapcolor+"\" FACE=\""+ocaptionfont+"\" SIZE=\""+ocaptionsize+"\">"+ocapicon+title+"</FONT></B></TD>"+closing+"</TR></TABLE><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 "+ofgcolor+" "+ofgbackground+" "+oheight+"><TR><TD VALIGN=TOP><FONT COLOR=\""+otextcolor+"\" FACE=\""+otextfont+"\" SIZE=\""+otextsize+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";set_background("");return txt;}
function ol_content_background(text,picture,hasfullhtml){if(hasfullhtml){txt=text;}else{if(ocss==CSSCLASS)txt="<TABLE WIDTH="+owidth+owidthunit+" BORDER=0 CELLPADDING=0 CELLSPACING=0 HEIGHT="+oheight+oheightunit+"><TR><TD COLSPAN=3 HEIGHT="+opadyt+opadunit+"></TD></TR><TR><TD WIDTH="+opadxl+opadunit+"></TD><TD VALIGN=TOP WIDTH="+(owidth-opadxl-opadxr)+opadunit+"><FONT class=\""+otextfontclass+"\">"+text+"</FONT></TD><TD WIDTH="+opadxr+opadunit+"></TD></TR><TR><TD COLSPAN=3 HEIGHT="+opadyb+opadunit+"></TD></TR></TABLE>";if(ocss==CSSSTYLE)txt="<TABLE WIDTH="+owidth+owidthunit+" BORDER=0 CELLPADDING=0 CELLSPACING=0 HEIGHT="+oheight+oheightunit+"><TR><TD COLSPAN=3 HEIGHT="+opadyt+opadunit+"></TD></TR><TR><TD WIDTH="+opadxl+opadunit+"></TD><TD VALIGN=TOP WIDTH="+(owidth-opadxl-opadxr)+opadunit+"><FONT style=\"font-family: "+otextfont+";color: "+otextcolor+";font-size: "+otextsize+otextsizeunit+";\">"+text+"</FONT></TD><TD WIDTH="+opadxr+opadunit+"></TD></TR><TR><TD COLSPAN=3 HEIGHT="+opadyb+opadunit+"></TD></TR></TABLE>";if(ocss==CSSOFF)txt="<TABLE WIDTH="+owidth+" BORDER=0 CELLPADDING=0 CELLSPACING=0 HEIGHT="+oheight+"><TR><TD COLSPAN=3 HEIGHT="+opadyt+"></TD></TR><TR><TD WIDTH="+opadxl+"></TD><TD VALIGN=TOP WIDTH="+(owidth-opadxl-opadxr)+"><FONT FACE=\""+otextfont+"\" COLOR=\""+otextcolor+"\" SIZE=\""+otextsize+"\">"+text+"</FONT></TD><TD WIDTH="+opadxr+"></TD></TR><TR><TD COLSPAN=3 HEIGHT="+opadyb+"></TD></TR></TABLE>";}
set_background(picture);return txt;}
function set_background(pic){if(pic==""){if(ie4)over.backgroundImage="none";if(ns6)over.style.backgroundImage="none";}else{if(ns4){over.background.src=pic;}else if(ie4){over.backgroundImage="url("+pic+")";}else if(ns6){over.style.backgroundImage="url("+pic+")";}}}
function disp(statustext){if((ns4)||(ie4)||(ns6)){if(oallowmove==0){placeLayer();showObject(over);oallowmove=1;}}
if(statustext !=""){self.status=statustext;}}
function placeLayer(){var placeX,placeY;if(ofixx>-1){placeX=ofixx;}else{winoffset=(ie4)? oframe.document.body.scrollLeft:oframe.pageXOffset;if(ie4)iwidth=oframe.document.body.clientWidth;if(ns4)iwidth=oframe.innerWidth;if(ns6)iwidth=oframe.outerWidth;if(ohauto==1){if((ox-winoffset)>((eval(iwidth))/ 2)){ohpos=7;}else{ohpos=8;}}
if(ohpos==9){placeX=ox+ooffsetx-(owidth/2);}
if(ohpos==8){placeX=ox+ooffsetx;if((eval(placeX)+eval(owidth))>(winoffset+iwidth)){placeX=iwidth+winoffset-owidth;if(placeX<0)placeX=0;}}
if(ohpos==7){placeX=ox-ooffsetx-owidth;if(placeX<winoffset)placeX=winoffset;}
if(osnapx>1){var snapping=placeX % osnapx;if(ohpos==7){placeX=placeX-(osnapx+snapping);}else{placeX=placeX+(osnapx-snapping);}
if(placeX<winoffset)placeX=winoffset;}}
if(ofixy>-1){placeY=ofixy;}else{scrolloffset=(ie4)? oframe.document.body.scrollTop:oframe.pageYOffset;if(ovauto==1){if(ie4)iheight=oframe.document.body.clientHeight;if(ns4)iheight=oframe.innerHeight;if(ns6)iheight=oframe.outerHeight;iheight=(eval(iheight))/ 2;if((oy-scrolloffset)> iheight){ovpos=35;}else{ovpos=36;}}
if(ovpos==35){if(oaboveheight==0){var divref=(ie4)? oframe.document.all['overDiv']:over;oaboveheight=(ns4)? divref.clip.height:divref.offsetHeight;}
placeY=oy-(oaboveheight+ooffsety);if(placeY<scrolloffset)placeY=scrolloffset;}else{placeY=oy+ooffsety;}
if(osnapy>1){var snapping=placeY % osnapy;if(oaboveheight>0&&ovpos==35){placeY=placeY-(osnapy+snapping);}else{placeY=placeY+(osnapy-snapping);}
if(placeY<scrolloffset)placeY=scrolloffset;}}
repositionTo(over,placeX,placeY);}
function mouseMove(e){if((ns4)||(ns6)){ox=e.pageX;oy=e.pageY;}
if(ie4){ox=event.x;oy=event.y;}
if(ie5){ox=event.x+oframe.document.body.scrollLeft;oy=event.y+oframe.document.body.scrollTop;}
if(oallowmove==1){placeLayer();}}
function cClick(){hideObject(over);oshowingsticky=0;return false;}
function compatibleframe(frameid){if(ns4){if(typeof frameid.document.overDiv=='undefined')return false;}else if(ie4){if(typeof frameid.document.all["overDiv"]=='undefined')return false;}else if(ns6){if(frameid.document.getElementById('overDiv')==null)return false;}
return true;}
function layerWrite(txt){txt+="\n";if(ns4){var lyr=oframe.document.overDiv.document
lyr.write(txt)
lyr.close()
}else if(ie4){oframe.document.all["overDiv"].innerHTML=txt
}else if(ns6){range=oframe.document.createRange();range.setStartBefore(over);domfrag=range.createContextualFragment(txt);while(over.hasChildNodes()){over.removeChild(over.lastChild);}
over.appendChild(domfrag);}}
function showObject(obj){if(ns4)obj.visibility="show";else if(ie4)obj.visibility="visible";else if(ns6)obj.style.visibility="visible";}
function hideObject(obj){if(ns4)obj.visibility="hide";else if(ie4)obj.visibility="hidden";else if(ns6)obj.style.visibility="hidden";if(otimerid>0)clearTimeout(otimerid);if(odelayid>0)clearTimeout(odelayid);otimerid=0;odelayid=0;self.status="";}
function repositionTo(obj,xL,yL){if((ns4)||(ie4)){obj.left=xL;obj.top=yL;}else if(ns6){obj.style.left=xL+"px";obj.style.top=yL+"px";}}
function opt_FRAME(frm){oframe=compatibleframe(frm)? frm:ol_frame;if((ns4)||(ie4 ||(ns6))){if(ns4)over=oframe.document.overDiv;if(ie4)over=oframe.overDiv.style;if(ns6)over=oframe.document.getElementById("overDiv");}
return 0;}
function opt_FUNCTION(callme){otext=callme()
return 0;
}
