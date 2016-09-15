$(document).ready(function(){
	$(document).on('change','#report_type',function(){
		value = $('#report_type').val();

		if (value != ''){
			$.ajax({
				url: '/cpm_reports/get_filter_'+value,
				async: false,
				success: function(data){
					$('#report_options_div').html(data["filter"]);
				}
			});
		} else {
			$('#report_options_div').html("");
		}

	});
});