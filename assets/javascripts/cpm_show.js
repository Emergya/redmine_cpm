$(document).ready(function(){
	//add_filter('users');

	$(document).tooltip({
		open: function (event, ui) {
        	ui.tooltip.css("max-width", "100%");
    	}
    });
	// Load new filter
	$('#select_filter').change(function(){
		select_value = $(this).val();
		html = "";

		add_filter(select_value);
	});

	// Enable/Disable filters
	$(document).on('click','.enable_filter',function(){
		id = $(this)[0].id

		if ($(this).is(':checked')){
			$('.'+id).prop('disabled',false);
			$('.'+id).show();
		} else {
			$('.'+id).prop('disabled',true);
			$('.'+id).hide();		
		}
	});

	// Show capacities search result
	$('#find_capacities').on('ajax:success', function(data, status, xhr){
		$('#capacity_modal').html(status);
		apply_options();
		clear_disabled_filters();
	});

	// Click on option "Hide empty rows"
	$(document).on('change','#hide_empty_users',function(){
		if ($(this).is(':checked')){
			hide_empty_results();
		} else {
			show_all_results();
		}

		strip_table("capacity_results");
	});

	// Click on option "Bar view"
	$(document).on('change','#bar_view',function(){
		if ($(this).is(':checked')){
			view_bars();
		} else {
			view_numbers();
		}
	});

	// Update user capacity edition
	$(document).on('ajax:success', '.edit_cpm_user_capacity', function(data, status, xhr){
		$('#dialog').html(status);
	});

	$(document).on('ajax:success', '.new_cpm_user_capacity', function(data, status, xhr){
		$('#dialog').html(status);
	});

});

// Show the specified filter
function add_filter(filter_name,show_banned,options){
	if ($.isNumeric(filter_name)){
		url = "custom_field/"+filter_name;
	} else {
		url = filter_name
	}

	data = {}
	if (show_banned == true){
		data['show_banned_'+filter_name] = show_banned;
		data[filter_name]=options;
	} else {
		data[filter_name]=options;
	}

	$.ajax({
		url: '/cpm_management/get_filter_'+url,
		data: data,
		async: false,
		success: function(filter){
			html = filter;
		}
	});

	// Show filter options
	if ($('#active_filters #'+filter_name).length != 0){
		$('#active_filters #'+filter_name).append(html['filter'])
	} else {
		$('#active_filters').append("<div id='"+filter_name+"' class='filter'>"+html['filter']+"</div>");
	}
	
	// Disable filter option in 'Add filter' list
	$('option[value='+filter_name+']').prop('disabled',true);
	$('#select_filter').val("default");
}

function update_filter(filter_name,show_banned,options){
	// Delete specified filter
	$('#'+filter_name).empty();

	options_arr = [];
	$.each(options, function(i,option){
		options_arr.push(option['value']);
	});
	// Show specified filter
	add_filter(filter_name,show_banned,options_arr);
}

// Hide all user rows with all capacities empty
function hide_empty_results(){
	$.each($('#capacity_results tr'),function(i,row){
		if (i>0){
			empty = true;
		
			$.each($('td',row),function(j,col){
				if (j>0 && $(col).attr('value')!=0){
					empty = false;
				}
			});

			if (empty){
				$(row).hide();
			}
		}
	});
}

// Show all user rows
function show_all_results(){
	$.each($('#capacity_results tr'),function(i,row){
		$(row).show();
	});
}

// Añade alternativamente las clases odd y even a las filas de la tabla indicada
function strip_table(table_id){
	nxt = 'odd';
	$('#'+table_id+' tbody tr').each(function(i,tr){
		if (i>0 && $(tr).is(':visible')){
			$(this).removeClass('even').removeClass('odd');
			$(this).addClass(nxt);

			if (nxt=='odd'){
				nxt = 'even';
			} else {
				nxt = 'odd';
			}
		}
	});
}

// Change capacity view mode to bars
function view_bars(){
	$.each($('#capacity_results tr'),function(i,row){
		if (i>0){
			$.each($('td',row),function(j,col){
				if (j>0){
					value = $(col).attr('value');
					fill_bar = parseInt(value/2);
					empty_bar = 50-fill_bar;
					$(col).html("<div class='bar_background'><div style='height:"+empty_bar+"px;' class='bar_empty'></div></div>")
				}
			});
		}
	});
}

// Change capacity view mode to numbers
function view_numbers(){
	$.each($('#capacity_results tr'),function(i,row){
		if (i>0){
			$.each($('td',row),function(j,col){
				if (j>0){
					value = $(col).attr('value');
					$(col).html(value)
				}
			});
		}
	});
}

// Apply actual visualization options to the result table
function apply_options(){
	if ($('#bar_view').is(':checked')){
		view_bars();
	} else {
		view_numbers();
	}

	if ($('#hide_empty_users').is(':checked')){
		hide_empty_results();
	} else {
		show_all_results();
	}

	strip_table("capacity_results");
}

// Remove disabled filters
function clear_disabled_filters(){
	$.each($('.filter'),function(index,filter){
		if (!$('input.enable_filter',filter).is(':checked')){
			$('option[value='+filter.id+']').prop('disabled',false);
			$(filter).remove();
		}
	});
}

// Generate and show modal window for user capacity edition
function edit_capacities(id,from_date,to_date,projects){
	html = "";

	$.ajax({
		url: '/cpm_management/edit_form/'+id,
		async: false,
		data: {projects: projects, from_date: from_date, to_date: to_date, ignore_blacklists: $('input[name="ignore_blacklists"]').serialize()},
		type: 'POST',
		success: function(filter){
			html = filter;
		}
	});

	$('#dialog').html(html);
	//830
	$('#dialog').dialog({width:1070, modal:true, close: function(){ 
		$('.ui-dialog').remove();
		enable_remote_submit('find_capacities', '/cpm_management/planning');
		$('#find_capacities').submit();
		disable_remote_submit('find_capacities', '/cpm_management/show');
	} });

}

function enable_remote_submit(form_id, action){
	$('#'+form_id).attr('data-remote','true');
	$('#'+form_id).attr('action',action);
}

function disable_remote_submit(form_id, action){
	$('#'+form_id).attr('action',action);
	$('#'+form_id).removeAttr('data-remote');
	$('#'+form_id).removeData("remote");
}