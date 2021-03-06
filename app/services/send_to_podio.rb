class SendToPodio
  UNIVERSITY_ID_PATTERN = /^Universidade[0-9]*$/
  @@expires_at = 0

  def self.call(params)
    new(params).call
  end

  attr_reader :params, :gx_participant, :status

  def initialize(params)
    @params = params
    @gx_participant = ExchangeParticipant.find_by(id: params['exchange_participant_id']).registerable
    @status = true
  end

  def call
    Shoryuken.logger.info("=>SQS PARAMS:\n=>#{@params}\n=>SQS PARAMS END")

    @status = send_to_podio(@params)
  end

  def utm_source_to_podio(db_source)
    podio_domains = {
      'rdstation': 1,
      'google': 2,
      'facebook': 3,
      'facebook-ads': 11,
      'instagram': 4,
      'twitter': 5,
      'twitter-ads': 12,
      'linkedin': 6,
      'linkedin-ads': 13,
      'youtube': 14,
      'site': 7,
      'blog': 8,
      'offline': 9,
      'outros': 10
    }

    podio_domain = podio_domains[db_source.downcase.to_sym]

    return podio_domains[:outros] unless podio_domain

    podio_domain
  end

  def utm_medium_to_podio(db_medium)
    podio_domains = {
      'banner': 19,
      'banner-home': 1,
      'pop-up': 10,
      'post-form': 12,
      'imagem': 7,
      'interacao': 20,
      'post-blog': 11,
      'post-link': 13,
      'stories': 15,
      'video': 17,
      'lead-ads': 9,
      'cpc': 4,
      'display': 5,
      'search': 14,
      'imagem-unica': 21,
      'cartaz': 3,
      'evento': 22,
      'indicacao': 8,
      'outro': 18,
      'panfleto': 23,
      'email': 6,
      'bumper': 2,
      'trueview': 16
    }

    podio_domain = podio_domains[db_medium.downcase.to_sym]

    return podio_domains[:outro] unless podio_domain

    podio_domain
  end

  private

  def send_to_podio(params)
    podio_id = nil
    params['podio_app'] ||= 152_908_22

    if expired_token?
      setup_podio
      auth = authenticate_podio
      @@expires_at = auth.expires_at
    end

    podio_id = Podio::Item.create(params['podio_app'], fields: podio_item_fields(params)).item_id

    podio_id
  end

  def update_participant(podio_id)
    @gx_participant.exchange_participant.update_attributes(podio_id: podio_id)

    upload_files(podio_id, @gx_participant) if gx_participant.try(:curriculum)&.attached?
  end

  def upload_files(podio_id, gx_participant)
    link = Rails.application.routes.url_helpers.rails_blob_path(gx_participant.curriculum, only_path: true)
    uploaded_file = Podio::FileAttachment.upload_from_url("#{ENV['BASE_URL']}#{link}")

    Podio::FileAttachment.attach(uploaded_file.file_id, 'item', podio_id)
  end

  def expired_token?
    Podio.client.nil? || @@expires_at == 0 || @@expires_at < (Time.now + 600)
  end

  def authenticate_podio
    Podio.client.authenticate_with_credentials(
      ENV['PODIO_USERNAME'],
      ENV['PODIO_PASSWORD']
    )
  end

  def setup_podio
    Podio.setup(
      api_key: ENV['PODIO_API_KEY'],
      api_secret: ENV['PODIO_API_SECRET']
    )
  end

  def podio_item_fields(params)
    if ENV['COUNTRY'] == 'bra'
      podio_item_fields_bra(params)
    else
      podio_item_fields_arg(params)
    end
  end

  def podio_item_fields_arg(sqs_params)
    params = {
      'sign-up-date' => { 'start' => Time.now.strftime('%Y-%m-%d %H:%M:%S') },
      'fullname' => sqs_params['fullname'],
      'email' => [{ 'type' => 'home', 'value' => sqs_params['email'] }],
      'cellphone' => [{ 'type' => 'home', 'value' => sqs_params['cellphone'] }],
      'birthdate' => {
        start: Date.parse(sqs_params['birthdate'].to_s).strftime('%Y-%m-%d %H:%M:%S')
      },
      'local-committee' => sqs_params['local_committee']
    }

    params['scholarity'] = sqs_params['scholarity'] + 1 if sqs_params['scholarity']
    params['university'] = sqs_params['university'].to_i if sqs_params['university']
    params['college-course'] = sqs_params['college_course'].to_i if sqs_params['college_course']
    params['other-university'] = sqs_params['other_university'] if sqs_params['other_university']
    params['cellphone-contactable'] = cellphone_contactable_option(sqs_params['cellphone_contactable'])
    params['utm-source'] = sqs_params['utm_source'] if sqs_params['utm_source']
    params['utm-medium'] = sqs_params['utm_medium'] if sqs_params['utm_medium']
    params['utm-campaign'] = sqs_params['utm_campaign'] if sqs_params['utm_campaign']
    params['utm-term'] = sqs_params['utm_term'] if sqs_params['utm_term']
    params['utm-content'] = sqs_params['utm_content'] if sqs_params['utm_content']
    params['english-level'] = sqs_params['english_level'] if sqs_params['english_level']
    params['referral-type'] = sqs_params['referral_type'] if valid_referral_type(sqs_params)

    # Podio starts counting at 1 instead of 0, so we increment our enum indexes to match its category field in the podio app.
    params['when-can-travel'] = sqs_params['when_can_travel'] + 1 if sqs_params['when_can_travel']

    params['preferred-destination'] = sqs_params['preferred_destination'] if sqs_params['preferred_destination']

    unless gv_participant?
      params['curriculum'] = @gx_participant.try(:curriculum)&.attached? ? 1 : 2
    end

    params
  end

  def valid_referral_type(params)
    params['referral_type'] && params['referral_type'].to_i > 0
  end

  def podio_item_fields_bra(sqs_params)
    params = {
      'data-inscricao' => { 'start' => Time.now.strftime('%Y-%m-%d %H:%M:%S') },
      'title' => sqs_params['fullname'],
      'email' => [{ 'type' => 'home', 'value' => sqs_params['email'] }],
      'telefone' => [{ 'type' => 'home', 'value' => sqs_params['cellphone'] }],
    }


    params['data-de-nascimento'] = { start: Date.parse(sqs_params['birthdate'].to_s).strftime('%Y-%m-%d %H:%M:%S') } if sqs_params['birthdate']

    params['tag-origem-2'] = utm_source_to_podio(sqs_params['utm_source']) if sqs_params['utm_source']
    params['tag-meio-2'] = utm_medium_to_podio(sqs_params['utm_medium']) if sqs_params['utm_medium']
    params['tag-campanha'] = sqs_params['utm_campaign'] if sqs_params['utm_campaign']
    params['tag-termo'] = sqs_params['utm_term'] if sqs_params['utm_term']
    params['tag-conteudo-2'] = sqs_params['utm_content'] if sqs_params['utm_content']
    params['escolaridade'] = scholarity_name(sqs_params['scholarity']) if sqs_params['scholarity']
    params['cl-marcado-no-expa-nao-conta-expansao-ainda'] = sqs_params['local_committee'] if sqs_params['local_committee']
    params['nivel-de-ingles'] = sqs_params['english_level'] if sqs_params['english_level']
    params['nivel-de-espanhol'] = sqs_params['spanish_level'] if sqs_params['spanish_level']
    params['universidade'] = sqs_params['university'].to_i if sqs_params['university']
    params['curso'] = sqs_params['college_course'].to_i if sqs_params['college_course']
    params['sub-produto'] = sqs_params['experience'] if sqs_params['experience']
    params['gostaria-de-ser-contactado-por-celular'] = cellphone_contactable_option(sqs_params['cellphone_contactable'])
    if params['nivel-de-ingles']
      params['nivel-de-ingles'] = 5 if params['nivel-de-ingles'].zero?
    end
    if params['nivel-de-espanhol']
      params['nivel-de-espanhol'] = 5 if params['nivel-de-espanhol'].zero?
    end
    params
  end

  def scholarity_name(index)
    ExchangeParticipant.brazilian_scholarity(ExchangeParticipant::BRAZILIAN_SCHOLARITY[index])
  end

  def cellphone_contactable_option(value)
    value ? 1 : 2
  end

  def registerable_class_name
    @gx_participant.class.name
  end

  def gt_participant?
    registerable_class_name == 'GtParticipant'
  end

  def gv_participant?
    registerable_class_name == 'GvParticipant'
  end
end
