# frozen_string_literal: true

# This is just a thin wrapper around the API's data structure which is a little
# heterogeneous. There's one Inventory Record for the Form's overall capacity
# (called 'quantity'); plus one for each ticket level's quantity for "limited supply"
# ticket levels; and then one record for each date/time per ticket level (again,
# not including ticket levels without "limited supply" set. I think?). The
# 'path', 'name', and 'key' fields tell you what you're looking at. 'sold' and
# 'quantity' are the numbers.
#
#   When there are two ticket levels to a "recurring" type Form, both set to have a limited supply:
#   path: "tickets",                  name: "tickets"                             # overall capacity for the whole Form
#   path: "tickets.adult",            name: "General Admission"                   # ticket-level capacity (my default ticket level)
#   path: "tickets.standingRoomOnly", name: "Standing Room Only"                  # ticket-level capacity for a second level
#   path: "tickets",                  name: "tickets-2022-07-22 20:00"            # sales data for all ticket levels of a performance (this is sometimes wrong)
#   path: "tickets.adult",            name: "General Admission-2022-07-22 20:00"  # sales data for the first, default ticket level of that performance
#   path: "tickets.standingRoomOnly", name: "Standing Room Only-2022-07-22 20:00" # sales data for a second ticket level of that performance
#
#   When the first, default ticket level does not have a limited supply:
#   path: "tickets",             name: "tickets"                                  # overall capacity for the whole Form
#   path: "tickets.rushTickets", name: "Rush Tickets"                             # ticket-level capacity for a second level
#   path: "tickets",             name: "tickets-2022-07-22 20:00"                 # sales data for the first, default ticket level of that performance?
#   path: "tickets.rushTickets", name: "Rush Tickets-2022-07-22 20:00"            # sales data for a second ticket level of that performance
#
# Unfortunately, we have run into situations where the overall sales data
# is not correct when one or more ticket levels do not have "limited supply"
# set. It seems that these sales are not included in the totals.
#
# The 'key' field is the part of the 'name' field after the hyphen and
# identifies the individual performance/showing/etc. and indicates that you're
# looking at its sales data. For my data from Ticketspice, for "recurring" events,
# the key is always the same datetime string as the part after the hyphen. For
# "multiple" events, it is an abbreviated event list key like "event1" or
# "may1stGrandFinale". "Single" type forms do not have these per-show records,
# just the overall capacity records, which have no 'key' field for all event types.
#
# n.b. the 'quantity' fields change retroactively when you adjust them in the
# web interface. So be careful making assumptions about old shows if you
# increase capacity during a run.
class WebconnexAPI::InventoryRecord < OpenStruct
  # TODO OpenStruct is bad for bugs and security read its rdoc.

  def self.all_by_form_id(form_id)
    # TODO: this fails for unpublished forms (see fixture 481580)
    json = WebconnexAPI.get_request("/forms/#{form_id}/inventory")
    irs = JSON.parse(json, object_class: self).data
    irs.each do |ir|
      ir.form_id = form_id
    end
    irs
  end

  def form
    raise "form_id isn't set" if form_id.nil?
    @form ||= WebconnexAPI::Form.find(form_id)
  end

  def event_time
    return @event_time if !@event_time.nil?

    if !single_performance_sales_record?
      # It's probably a mistake to call this method on a record not related to
      # an individual performance.
      raise "This Inventory Record is not related to an individual " +
            "performance, so it doesn't have a time (#{self.inspect})"
    elsif form.single? && form.event_start?
      @event_time = form.event_start
    elsif form.single? && !form.event_start?
      # TODO: find out whether this is possible
      raise %Q{This Inventory Record is for a Form with "eventType"="single", } +
            %Q{but no "eventStart" set on the Form. That's not implemented yet.}
    elsif form.recurring? && form.event_start? && event_has_date_but_no_time? &&
            single_performance_sales_record_for_first_performance?
      # Special case: when we set up a recurring form, set the form's "event
      # start" to the first performance's start time, set a recurring schedule,
      # but don't add time slots, the inventory record keys will only have a
      # date, no time. For the first recurring performance, we can infer the
      # time from the form's "event start". After that, probably safer not to.
      #
      # TODO: this is a complicated edge case that adds a lot of complexity here
      # and elsewhere. Which show caused this issue and is there a simpler way?
      changed = form.event_start.change(year:  time_from_key_in_event_tz.year,
                                        month: time_from_key_in_event_tz.month,
                                        day:   time_from_key_in_event_tz.day)
      # Something about our Time object receiving #change makes it return a new
      # object with the machine's TZ slapped on it intead of the receiver's TZ,
      # therefore changing other fields inadvertently. This dance fixes it.
      # TODO: figure out why this is happening, DRY up the pattern
      @event_time = form.time_zone.to_local(form.time_zone.local_to_utc(changed))
    elsif form.multiple?
      event_label = form.event_list[key]
      @event_time = form.guessed_event_date_for_event_list_name(event_label)
    else
      @event_time = time_from_key_in_event_tz
    end
  end

  def event_date
    event_time.to_date
  end

  def upcoming?
    if event_has_date_but_no_time?
      event_date >= Date.today
    else
      event_time >= Time.now
    end
  end

  def past?
    !upcoming?
  end

  # When you put a show on sale, sell tickets, then later move/refund all the
  # orders and hide the show using an Action, you'll still get an Inventory
  # Record back showing zero tickets sold. This doesn't happen for shows that
  # never sell a ticket. So, checking for this is one way to fix up junk data
  # without fully implementing the Actions' logic. (And keeping track of what
  # that logic was as of the time of each show.)
  def none_sold?
    sold.zero?
  end

  def event_has_date_but_no_time?
    key =~ /^\d\d\d\d-\d\d-\d\d$/
  end

  def single_performance_sales_record?
    form.single? || !key.nil?
  end

  private def key_format
    if event_has_date_but_no_time?
      "%Y-%m-%d"
    else
     "%Y-%m-%d %H:%M"
    end
  end

  private def time_from_key_in_event_tz
    raise "keys are blank for single events" if form.single?
    in_machine_zone = Time.strptime(key, key_format)
    in_utc = form.time_zone.local_to_utc(in_machine_zone) # this disregards the object's TZ
    form.time_zone.to_local(in_utc)
  end

  def single_performance_sales_record_for_first_performance?
    return true if form.single?
    return false if !single_performance_sales_record?

    if event_has_date_but_no_time?
      form.first_performance_date.to_date == time_from_key_in_event_tz.to_date
    else
      form.first_performance_date == time_from_key_in_event_tz
    end
  end

  def overall_capacity_record?
    !single_performance_sales_record? && path == "tickets"
  end

  def single_performance_total_sales_record?
    single_performance_sales_record? && path == "tickets"
  end

  def single_performance_ticket_level_sales_record?
    single_performance_sales_record? && path.start_with?("tickets.")
  end
end
