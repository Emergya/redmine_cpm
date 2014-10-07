class CpmUserCapacityController < ApplicationController
  unloadable

  def new_by_assignment
    new
    redirect_to controller:'cpm_management', action: 'assignments'
  end

  def new_by_modal
    new
    redirect_to  controller:'cpm_management', action:'edit_form', 
                    user_id:@cpm_user_capacity.user_id, 
                    from_date:params[:start_date], 
                    to_date:params[:due_date], 
                    projects:params[:projects]
  end

  # Add new capacity to an user for a project
  def new
    data = params[:cpm_user_capacity]

  	@cpm_user_capacity = CpmUserCapacity.new(data)

  	if @cpm_user_capacity.save
  		flash[:notice] = l(:"cpm.msg_save_success")  
    else
  		flash[:error] = @cpm_user_capacity.get_error_message
    end
  end

  # Edit a capacity for an user
  def edit
    cpm = CpmUserCapacity.find_by_id(params[:id])
    data = params[:cpm_user_capacity]
    data[:project_id] = data[:project_id].to_i

    if cpm.update_attributes(data)
      flash[:notice] = l(:"cpm.msg_edit_success")
    else
      flash[:error] = cpm.get_error_message
    end

    redirect_to controller:'cpm_management' ,action:'edit_form', 
                user_id:cpm.user_id, 
                from_date:params[:start_date], 
                to_date:params[:due_date], 
                projects:params[:projects]
  end

  def delete
    cpm = CpmUserCapacity.find_by_id(params[:id])

    if cpm.destroy
      flash[:notice] = l(:"cpm.msg_delete_success")
    else
      flash[:error] = cpm.get_error_message
    end

    redirect_to controller:'cpm_management', action:'edit_form', 
                user_id:cpm.user_id, 
                from_date:params[:start_date], 
                to_date:params[:due_date], 
                projects:params[:projects]
  end
end