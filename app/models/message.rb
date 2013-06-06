class Message < ActiveRecord::Base
  attr_accessible :impact_statement, :other_services, :purpose, :resolution, :sender_uid, :subject, :window_end, :window_start, :workaround, :classification_id, :modifier_id, :recipient_uids, :messenger_event_ids, :impacted_service_ids
  has_many :damages
  has_many :impacted_services, :through => :damages
  
  has_many :broadcasts
  has_many :messenger_events, :through => :broadcasts
  
  has_many :audiences
  has_many :recipients, :through => :audiences
  
  belongs_to :classification
  belongs_to :modifier

  # Filters to limit the result to specified criterion
  scope :by_classification, lambda { |classification| where(classification_id: classification) unless classification.nil? }
  scope :by_modifier, lambda { |modifier| where(modifier_id: modifier) unless modifier.nil? }
  scope :by_service, lambda { |service| joins(:impacted_services).where('impacted_services.id = ?', service) unless service.nil? }
  scope :by_mevent, lambda { |mevent| joins(:messenger_events).where('messenger_events.id = ?', mevent) unless mevent.nil? }
  
  def recipient_uids=(ids_str)
    ids_str.split(",").each do |r|
      recipient = Recipient.find_or_create_by_uid(r)
      self.recipients << recipient
    end
  end
  
  #DssMailer.delay.deliver_message(@message) if @message.messenger_event_ids.include? 1 # 1=send email?
  def send_mass_email()
    self.recipients.each do |r|
      # Look up e-mail address for r.uid
      @entity = Entity.find(r.uid)
      if @entity.type == "Group"
        @entity.members.each do |m|
          # Send the e-mail
          @member = Person.find(m.id)
          DssMailer.delay.deliver_message(self,@member)
        end
      elsif @entity.type == "Person"
        # Send the e-mail
        @member = Person.find(@entity.id)
        DssMailer.delay.deliver_message(self,@member)
      end
    end
  end
  
  def as_json(options = {})
    {
      :id => self.id,
      :impact_statement => self.impact_statement,
      :other_services => self.other_services,
      :purpose => self.purpose,
      :resolution => self.resolution,
      :sender_uid => self.sender_uid,
      :subject => self.subject,
      :window_start => 
        if self.window_start
          self.window_start.strftime("%Y/%m/%d %I:%M %p")
        else
          self.window_start
        end,
      :window_end =>
        if self.window_end
          self.window_end.strftime("%Y/%m/%d %I:%M %p")
        else
          self.window_end
        end,
      :workaround => self.workaround,
      :classification_id => self.classification_id,
      :classification => self.classification,
      :modifier_id => self.modifier_id,
      :modifier => self.modifier,
      :recipients => self.recipients,
      :recipient_ids => self.recipients.pluck(:recipient_id),
      :recipient_uids => self.recipients.pluck(:uid),
      :impacted_services => self.impacted_services,
      :impacted_service_ids => self.impacted_services.pluck(:impacted_service_id),
      :messenger_events => self.messenger_events,
      :messenger_event_ids => self.messenger_events.pluck(:messenger_event_id),
      :created_at => self.created_at.strftime("%b %d %I:%M %P")
    }
    
  end
end
