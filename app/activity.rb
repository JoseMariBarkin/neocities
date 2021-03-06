get '/activity' do
  #expires 7200, :public, :must_revalidate if self.class.production? # 2 hours
  params[:activity] = 'global' # FIXME this is a bad hack

  global_dataset = Event.global_dataset

  if params[:event_id]
    global_dataset.where! Sequel.qualify(:events, :id) => params[:event_id]
  end

  initial_events = global_dataset.all
  events = []

  initial_events.each do |event|
    site = Site.select(:id).where(id: event.site_id).first
    actioning_site = Site.select(:id).where(id: event.actioning_site_id).first

    disclude_event = false
    disclude_event = true if site.is_a_jerk?

    if event.tip_id
      disclude_event = true if actioning_site && actioning_site.is_a_jerk?
    else
      disclude_event = true if actioning_site && (actioning_site.is_a_jerk? || actioning_site.follows_dataset.count < 2)
    end

    events.push(event) unless disclude_event
  end

  initial_site_change_events = Event.global_site_changes_dataset.limit(100).all
  site_change_events = []

  initial_site_change_events.each do |event|
    site = Site.select(:id).where(id: event.site_id).first
    site_change_events.push(event) if !site.is_a_jerk? && site.follows_dataset.count > 1
  end

  @events = []

  events.each do |event|
    unless site_change_events.empty?
      until site_change_events.first.created_at < event.created_at
        @events << site_change_events.shift
        break if site_change_events.empty?
      end
    end
    @events << event
  end

  erb :'activity'
end
