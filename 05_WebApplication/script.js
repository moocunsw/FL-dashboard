function showChart(evt, chartName) {
    // Declare all variables
    var i, tabcontent, tablinks;

    // Get all elements with class="tabcontent" and hide them
    tabcontent = document.getElementsByClassName("tabcontent");
    for (i = 0; i < tabcontent.length; i++) {
        tabcontent[i].style.display = "none";
    }

    // Get all elements with class="tablinks" and remove the class "active"
    tablinks = document.getElementsByClassName("tablinks");
    for (i = 0; i < tabcontent.length; i++) {
        tablinks[i].className = tablinks[i].className.replace(" active", "");
    }

    // Show the current tab, and add an "active" class to the link that opened the tab
    document.getElementById(chartName).style.display = "block";
    evt.currentTarget.className += " active";
}

function refreshFrame(mychart,mycourse){
		
		if (mycourse==""){
			console.log('course empty, new course = ' + $('#course_select').find(":selected").val());

			mycourse= $('#course_select').find(":selected").val();
		}

		myurl="http://127.0.0.1:5819/?" + mychart + "/?course=" + mycourse;

		console.log(myurl);

        $("#myframe").attr("src", myurl);
	
    }

$(document).ready(function(){
	var mycourse = "";
	var mychart = "";
	var myurl = "";
	

    $("#course_select").change(function(){
        mycourse= $(this).val();
        console.log(mycourse);
    });
		
	
	$("#chart_select_demographic").change(function(){
		mychart = $.trim($(this).val());
		refreshFrame(mychart,mycourse);}
	);
	
	$("#chart_select_enrolment").change(function(){
		mychart = $.trim($(this).val());
		refreshFrame(mychart,mycourse);}
	);
	
	$("#chart_select_activity").change(function(){
		mychart = $.trim($(this).val());
		refreshFrame(mychart,mycourse);});
	
	$("#chart_select_comments").change(function(){
		mychart = $.trim($(this).val());
		refreshFrame(mychart,mycourse);});
	
	$("#chart_select_questionResponse").change(function(){
		mychart = $.trim($(this).val());
		refreshFrame(mychart,mycourse);});

});