/**/


$(document).ready(function(){
	$("dd:not(:first)").hide();
	$("dt a").click(function(){
		$("dd:visible").slideUp("fast");
		$(this).parent().next().slideDown("fast");
		return false;
	});
});
