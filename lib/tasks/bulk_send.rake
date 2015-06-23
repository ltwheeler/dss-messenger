require 'rake'

namespace :message do
  desc 'Publish a message'
  task :publish, [:message_log_id] => :environment do |t, args|
    Rails.logger.tagged('task:message:publish') do
      message_log = MessageLog.find_by_id(args.message_log_id)
      unless message_log
        Rails.logger.error "Unable to find message log with ID #{args.message_log_id}"
        next # used in rake to abort a rake task (as well as in loops)
      end

      message = message_log.message
      unless message
        Rails.logger.error "Unable to find message for message log with ID #{message_log.id}"
        next
      end

      timestamp_start = Time.now

      members = []

      # Resolve e-mail addresses for message recipients
      message.recipients.each do |r|
        begin
          entity = Entity.find(r.uid)
        rescue Exception => e
          Rails.logger.error "ActiveResource error while fetching entity with UID #{r.id}: '#{e}'. Skipping to next."
          next
        end

        unless entity
          Rails.logger.warning "Could not find entity with UID #{r.id}. Skipping to next."
          next
        end

        # If entity is a group, resolve individual group members
        if entity.type == "Group"
          entity.members.map(&:id).uniq.each do |m|
            begin
              p = Person.find(m)
            rescue Exception => e
              Rails.logger.error "ActiveResource error while fetching group member with UID #{m}: '#{e}'. Skipping to next group member."
              next
            end

            members << p
          end
        elsif entity.type == "Person"
          members << entity
        end
      end

      message_log.status = :sending
      message_log.start = Time.now
      message_log.recipient_count = members.length
      message_log.save!

      unique_members = members.uniq { |p| p.email }

      # TODO: Find a better way to add a whitelist to constantize. Monkey
      # patching probably not the best way.
      def String.constantize(camel_cased_word)
        super  if Dir.entries(Rails.root + "app/publishers")
          .map do |x| 
            unless x.starts_with? "."
              # Possible bug: Won't catch files that don't start with 
              # class XYZ < Publisher on the first line
              class_line = File.open(Rails.root + "app/publishers/" + x, &:readline)
              class_line.gsub(/.* (.*) < Publisher/, '\1')  if class_line.include? "< Publisher"
            end
          end
          .delete_if { |x| x.nil? }
          .include? camel_cased_word
      end
      message_log.publisher.class_name.constantize.schedule(message_log, message, unique_members)

      Rails.logger.info "Enqueueing message ##{args.message_id} for #{members.length} recipients took #{Time.now - timestamp_start} seconds"
    end
  end
end
