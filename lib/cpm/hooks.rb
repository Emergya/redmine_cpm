module CPM
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_welcome_index_right,
              :partial => 'hooks/cpm/view_welcome_index_right'
    render_on :view_projects_settings_members_table_header,
              :partial => 'hooks/cpm/view_projects_settings_members_table_header'
    render_on :view_projects_settings_members_table_row,
              :partial => 'hooks/cpm/view_projects_settings_members_table_row'
    render_on :view_projects_show_sidebar_bottom,
              :partial => 'hooks/cpm/view_projects_show_sidebar_bottom'
  end
end

