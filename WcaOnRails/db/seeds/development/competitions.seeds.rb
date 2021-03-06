after "development:users" do
  class << self
    def random_event_ids
      all_official = Event.all_official.map(&:id)
      all_official.sample(rand(1..all_official.count))
    end
  end

  delegate = User.find_by(delegate_status: "delegate")

  users = User.where.not(wca_id: nil).sample(93)

  # Create some past competitions with results
  2.times do |i|
    day = i.days.ago
    eventIds = random_event_ids

    competition = Competition.create!(
      id: "My#{i}ResultsComp#{day.year}",
      name: "My #{i} Comp With Results #{day.year}",
      cellName: "My #{i} Comp With Results #{day.year}",
      cityName: Faker::Address.city,
      countryId: Country::ALL_COUNTRIES.sample.id,
      information: "Information!",
      start_date: day.strftime("%F"),
      end_date: day.strftime("%F"),
      eventSpecs: eventIds.join(" "),
      venue: Faker::Address.street_name,
      website: "https://www.worldcubeassociation.org",
      showAtAll: true,
      delegates: [delegate],
      organizers: User.all.sample(2),
      use_wca_registration: true,
      registration_open: 2.weeks.ago,
      registration_close: 1.week.ago,
      latitude_degrees: Random.new.rand(-90.0..90.0),
      longitude_degrees: Random.new.rand(-180.0..180.0),
    )

    eventIds.each do |eventId|
      %w(1 2 f).each do |roundId|
        users.each_with_index do |competitor, i|
          person = competitor.person
          Result.create!(
            pos: i+1,
            personId: person.id,
            personName: person.name,
            countryId: person.countryId,
            competitionId: competition.id,
            eventId: eventId,
            roundId: roundId,
            formatId: "a",
            value1: 4242 + i*1000,
            value2: 4242 + i*1000,
            value3: 4242 + i*1000,
            value4: 6000 + i*1000,
            value5: 4000 + i*1000,
            best: 4000 + i*1000,
            average: 4242 + i*1000,
            regionalSingleRecord: i == 0 ? "WR" : "",
            regionalAverageRecord: i == 0 ? "WR" : "",
          )
        end
      end
    end
  end

  # Create a bunch of competitions just to fill up the competitions list

  # Past competitions
  500.times do |i|
    day = i.days.ago
    eventIds = random_event_ids
    Competition.create!(
      id: "My#{i}Comp#{day.year}",
      name: "My #{i} Best Comp #{day.year}",
      cellName: "My #{i} Comp #{day.year}",
      cityName: Faker::Address.city,
      countryId: Country::ALL_COUNTRIES.sample.id,
      information: "Information!",
      start_date: day.strftime("%F"),
      end_date: day.strftime("%F"),
      eventSpecs: eventIds.join(" "),
      venue: Faker::Address.street_name,
      website: "https://www.worldcubeassociation.org",
      showAtAll: true,
      delegates: [delegate],
      organizers: User.all.sample(2),
      use_wca_registration: true,
      registration_open: 2.weeks.ago,
      registration_close: 1.week.ago,
      latitude_degrees: Random.new.rand(-90.0..90.0),
      longitude_degrees: Random.new.rand(-180.0..180.0),
    )
  end

  users.each_with_index do |user, i|
    RanksAverage.create!(
      personId: user.wca_id,
      eventId: "333",
      best: "4242",
      worldRank: i,
      continentRank: i,
      countryRank: i,
    )

    RanksSingle.create!(
      personId: user.wca_id,
      eventId: "333",
      best: "2000",
      worldRank: i,
      continentRank: i,
      countryRank: i,
    )
  end

  # Upcoming competitions
  500.times do |i|
    eventIds = random_event_ids

    start_day = (i+1).days.from_now
    end_day = start_day + (0..5).to_a.sample.days
    end_day = start_day if start_day.year != end_day.year

    competition = Competition.create!(
      id: "MyComp#{i+1}#{start_day.year}",
      name: "My #{i+1} Comp #{start_day.year}",
      cellName: "My #{i+1} Comp #{start_day.year}",
      cityName: Faker::Address.city,
      countryId: Country::ALL_COUNTRIES.sample.id,
      information: "Information!",
      start_date: start_day.strftime("%F"),
      end_date:  end_day.strftime("%F"),
      eventSpecs: eventIds.join(" "),
      venue: Faker::Address.street_name,
      website: "https://www.worldcubeassociation.org",
      showAtAll: true,
      delegates: [delegate],
      organizers: User.all.sample(2),
      use_wca_registration: true,
      registration_open: 1.week.ago,
      registration_close: start_day - (1.week),
      latitude_degrees: Random.new.rand(-90.0..90.0),
      longitude_degrees: Random.new.rand(-180.0..180.0),
    )

    # Create registrations for some competitions taking place far in the future
    next if i < 480
    users.each_with_index do |user, i|
      status = i % 4 == 0 ? "a" : "p"
      registrationEventIds = eventIds.sample(rand(1..eventIds.count)).join(" ")
      if i % 2 == 0
        Registration.new(
          competition: competition,
          name: Faker::Name.name,
          personId: user.wca_id,
          countryId: Country::ALL_COUNTRIES.sample.id,
          gender: "m",
          birthYear: 1990,
          birthMonth: 6,
          birthDay: 4,
          email: Faker::Internet.email,
          guests: rand(10),
          comments: Faker::Lorem.paragraph,
          ip: "1.1.1.1",
          status: status,
          eventIds: registrationEventIds,
        ).save!(validate: false)
      else
        FactoryGirl.create(:registration, user: user, competition: competition, status: status, eventIds: registrationEventIds)
      end
    end
  end
end
