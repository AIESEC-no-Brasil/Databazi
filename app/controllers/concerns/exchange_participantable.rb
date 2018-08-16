module ExchangeParticipantable
  extend ActiveSupport::Concern

  def create
    if exchange_participantable.save
      SignUpWorker.perform_async(exchange_participantable.as_sqs)
      render json: { status: :success }
    else
      render json: {
        status: :failure,
        messages: exchange_participantable.errors.messages
      }
    end
  end
end
