module ExchangeParticipantable
  extend ActiveSupport::Concern
  def create
    if exchange_participantable.save
      perform_on_workers
      render json: { status: :success }
    else
      remove_campaign
      render json: {
        status: :failure,
        messages: exchange_participantable.errors.messages
      }
    end
  end

  private

  def perform_on_workers
    SendToPodioWorker.perform_async(ep_fields)
    SignUpWorker.perform_async(exchange_participantable.as_sqs)
    RdstationWorker.perform_async({ 'exchange_participant_id': self.id }) if ENV['COUNTRY'] == 'ita'
  end

  def remove_campaign
    campaign.destroy
  end
end
