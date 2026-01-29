/*
 * Tooltip script 
 * powered by jQuery (http://www.jquery.com)
 * 
 * written by Alen Grakalic (http://cssglobe.com)
 * 
 * for more info visit http://cssglobe.com/post/1695/easiest-tooltip-and-image-preview-using-jquery
 *
 */
 
/* 
 * modified <p> to </div> and position CSS.
 */


this.tooltip = function(){	
	/* CONFIG */		
		xOffset = -22;
		yOffset = 18;
		xadj = 7;
		// these 2 variable determine popup's distance from the cursor
		// you might want to adjust to get the right result		
	/* END CONFIG */		
	$("a.tooltip").hover(function(e){											  
		this.t = this.title;
		this.title = "";									  
		$("body").append("<div id='tooltip'>"+ this.t +"</div>");
		if(e.pageX >= document.documentElement.clientWidth*0.6){
			$("#tooltip")
				.css("top",(e.pageY - xOffset) + "px")
				.css("left","auto")
				.css("right",(document.documentElement.clientWidth - e.pageX + yOffset - xadj) + "px")
				.fadeIn("fast");
		}else{
			$("#tooltip")
				.css("top",(e.pageY - xOffset) + "px")
				.css("right","auto")
				.css("left",(e.pageX + yOffset) + "px")
				.fadeIn("fast");
		}
    },
	function(){
		this.title = this.t;		
		$("#tooltip").remove();
    });	
	$("a.tooltip").mousemove(function(e){
		if(e.pageX >= document.documentElement.clientWidth*0.6){
			$("#tooltip")
				.css("top",(e.pageY - xOffset) + "px")
				.css("left","auto")
				.css("right",(document.documentElement.clientWidth - e.pageX + yOffset - xadj) + "px");
		}else{
			$("#tooltip")
				.css("top",(e.pageY - xOffset) + "px")
				.css("right","auto")
				.css("left",(e.pageX + yOffset) + "px")
				.fadeIn("fast");
		}
	});			
};



// starting the script on page load
$(document).ready(function(){
	tooltip();
});

