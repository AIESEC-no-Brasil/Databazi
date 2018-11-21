module GtParticipantFields

  def gt_participant_fields
    if ENV['COUNTRY'] == 'bra'
      gt_participant_fields_bra
    else
      gt_participant_fields_arg
    end
  end

  def gt_participant_fields_bra
    {
      'email' => gt_participant.email,
      'fullname' => gt_participant.fullname,
      'cellphone' => gt_participant.cellphone,
      'birthdate' => gt_participant.birthdate,
      'utm_source' => utm_source,
      'utm_medium' => utm_medium,
      'utm_campaign' => utm_campaign,
      'utm_term' => utm_term,
      'utm_content' => utm_content,
      'podio_app' => 170_570_01,
      'scholarity' => scholarity_human_name,
      'local_committee' => gt_participant.exchange_participant&.local_committee&.podio_id,
      'english_level' => gt_participant&.english_level&.read_attribute_before_type_cast(:english_level),
      'university' => gt_participant.exchange_participant&.university&.podio_item_id,
      'college_course' => gt_participant.exchange_participant&.college_course&.podio_item_id,
      'experience' => gt_participant&.experience&.for_podio,
      'cellphone_contactable' => gt_participant.exchange_participant.cellphone_contactable
    }
  end

  def gt_participant_fields_arg
    {
      'email' => gt_participant.email,
      'fullname' => gt_participant.fullname,
      'cellphone' => gt_participant.cellphone,
      'birthdate' => gt_participant.birthdate,
      'utm_source' => utm_source,
      'utm_medium' => utm_medium,
      'utm_campaign' => utm_campaign,
      'utm_term' => utm_term,
      'utm_content' => utm_content,
      'podio_app' => 170_570_01,
      'scholarity' => scholarity_human_name,
      'local_committee' => gt_participant.exchange_participant&.local_committee&.podio_id,
      'english_level' => gt_participant&.english_level&.read_attribute_before_type_cast(:english_level),
      'university' => gt_participant.exchange_participant&.university&.podio_item_id,
      'college_course' => gt_participant.exchange_participant&.college_course&.podio_item_id,
      'experience' => gt_participant&.experience&.for_podio,
      'preferred_destination' => gt_participant.preferred_destination,
      'cv' => 0
    }
  end

end