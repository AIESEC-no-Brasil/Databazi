class ExpaPeopleSync
  def self.call(logger=nil)
    new.call logger
  end

  def call(logger=nil)
    logger = logger || Logger.new(STDOUT)

    load_expa_people(from) { |person| perform_on_exchange_participant(person) }
  end

  private

  def perform_on_exchange_participant(person)
    exchange_participant = ExchangeParticipant.find_by(expa_id: person.id)

    if exchange_participant && status_modified?(exchange_participant&.status, person&.status)
      exchange_participant.update_attributes(status: person.status.to_sym, updated_at_expa: person.updated_at)
      update_rd_station(exchange_participant)
    end
  end

  def load_expa_people(from, page = 1, &callback)
    res = query_all_people(from)

    total_pages = res&.data&.all_people&.paging&.total_pages

    people = res&.data&.all_people&.data
    people.each do |person|
      begin
        callback.call(person)
      rescue => exception
        Raven.extra_context exchange_participant_expa_id: person.id
        Raven.capture_exception(exception)
        logger = logger || Logger.new(STDOUT)
        logger.error exception.message
        logger.error(exception.backtrace.map { |s| "\n#{s}" })
        break
      end

    end if people

    people = nil

    return load_expa_people(
      from,
      page + 1,
      &callback
    ) unless res.nil? || page + 1 > total_pages
  end

  def from
    (ExchangeParticipant
      .order(updated_at_expa: :desc)
      .first&.updated_at_expa  || 7.days.ago) + 1
  end


  def status_modified?(status, expa_status)
    status != expa_status
  end

  def query_all_people(from)
    EXPAAPI::Client.query(
        ALLPEOPLE,
        variables: {
          from: from
        }
      )
  end

  def update_rd_station(exchange_participant)
    rdstation_integration = RdstationIntegration.new
    uuid = exchange_participant.rdstation_uuid

    unless uuid
      contact = rdstation_integration.fetch_contact_by_email(exchange_participant.email)
      uuid = contact['uuid'] if contact
      exchange_participant.update_attribute(:rdstation_uuid, uuid) if uuid
    end

    rdstation_integration.update_contact_by_uuid(uuid, { cf_status: exchange_participant.status }) if uuid
  end

  def rdstation_authentication_token
    rdstation_authentication = RDStation::Authentication.new(ENV['RDSTATION_CLIENT_ID'], ENV['RDSTATION_CLIENT_SECRET'])
    rdstation_authentication.auth_url(ENV['RDSTATION_REDIRECT_URL'])

    rdstation_authentication.update_access_token(ENV['RDSTATION_REFRESH_TOKEN'])['access_token']
  end

end

ALLPEOPLE = EXPAAPI::Client.parse <<~'GRAPHQL'
  query ($from: DateTime) {
    allPeople(per_page: 500, sort: "+updated_at",
              filters: {
                home_committee: 1553,
                last_interaction: { from: $from }
              }
    ) {
        paging {
          total_pages
        }
        data {
          id
          status
          updated_at
      }
    }
  }
GRAPHQL
