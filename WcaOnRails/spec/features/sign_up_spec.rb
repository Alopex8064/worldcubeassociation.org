require "rails_helper"

RSpec.feature "Sign up" do
  let!(:person) { FactoryGirl.create(:person_who_has_competed_once, year: 1988, month: 02, day: 03) }
  let!(:person_without_dob) { FactoryGirl.create :person, year: 0, month: 0, day: 0 }

  context 'when signing up as a returning competitor', js: true do
    it 'disables sign up button until the user selects "have competed"' do
      visit "/users/sign_up"

      expect(page).to have_selector('#unknown-competed', visible: true)
      expect(page).to have_button("Sign up", disabled: true)
      click_on "I have competed in a WCA competition."
      expect(page).to have_selector('#unknown-competed', visible: false)
      expect(page).to have_button("Sign up")
    end

    it 'finds people by name' do
      visit "/users/sign_up"

      fill_in "Email", with: "jack@example.com"
      fill_in "user[password]", with: "wca"
      fill_in "user[password_confirmation]", with: "wca"
      click_on "I have competed in a WCA competition."

      # They have not selected a valid WCA ID yet, so don't show the birthdate verification
      # field.
      expect(page.find("div.user_dob_verification", visible: false).visible?).to eq false

      selectize_input = page.find("div.user_unconfirmed_wca_id .selectize-control input")
      selectize_input.native.send_key(person.wca_id)
      # Wait for selectize popup to appear.
      expect(page).to have_selector("div.selectize-dropdown", visible: true)
      # Select item with selectize.
      page.find("div.user_unconfirmed_wca_id input").native.send_key(:return)

      # Wait for select delegate area to load via ajax.
      expect(page.find("#select-nearby-delegate-area")).to have_content "In order to assign you your WCA ID"

      # Now that they've selected a valid WCA ID, make sure the birthdate
      # verification field is visible.
      expect(page.find("div.user_dob_verification", visible: true).visible?).to eq true

      delegate = person.competitions.first.delegates.first
      choose("user_delegate_id_to_handle_wca_id_claim_#{delegate.id}")

      # First, intentionally fill in the incorrect birthdate,
      # to test out our validations.
      fill_in "Birthdate", with: "1900-01-01"
      click_button "Sign up"

      # Make sure we inform the user of the incorrect birthdate they just
      # entered.
      expect(page.find(".alert.alert-danger")).to have_content("Dob verification incorrect")
      # Now enter the correct birthdate and submit the form!
      fill_in "Birthdate", with: "1988-02-03"
      # We also have to re-fill in the password and password confirmation
      fill_in "user[password]", with: "wca"
      fill_in "user[password_confirmation]", with: "wca"
      click_button "Sign up"

      u = User.find_by_email!("jack@example.com")
      expect(u.name).to eq person.name
      expect(u.gender).to eq person.gender
      expect(u.country_iso2).to eq person.country_iso2

      expect(u.unconfirmed_wca_id).to eq person.wca_id
      expect(u.delegate_id_to_handle_wca_id_claim).to eq delegate.id

      expect(WcaIdClaimMailer).to receive(:notify_delegate_of_wca_id_claim).with(u).and_call_original
      expect do
        visit "/users/confirmation?confirmation_token=#{u.confirmation_token}"
      end.to change { ActionMailer::Base.deliveries.length }.by(1)
    end

    it "remembers that they have competed before on validation error" do
      visit "/users/sign_up"
      click_on "I have competed in a WCA competition."
      click_button "Sign up"

      expect(page).to have_selector('#have-competed', visible: true)
    end
  end

  context 'when signing up as a first time competitor', js: true do
    it 'can sign up' do
      visit "/users/sign_up"

      fill_in "Email", with: "jack@example.com"
      fill_in "user[password]", with: "wca"
      fill_in "user[password_confirmation]", with: "wca"

      # Check that we disable the sign up button until the user selects
      # "never competed".
      expect(page).to have_selector('#unknown-competed', visible: true)
      expect(page).to have_button("Sign up", disabled: true)
      click_on "I have never competed in a WCA competition."
      expect(page).to have_selector('#unknown-competed', visible: false)
      expect(page).to have_button("Sign up")

      fill_in "Full name", with: "Jack Johnson"
      fill_in "Birthdate", with: "1975-05-18"
      select "Male", from: "Gender"
      select "USA", from: "Citizenship"

      click_button "Sign up"

      expect(page).to have_content "A message with a confirmation link has been sent to your email address."

      u = User.find_by_email!("jack@example.com")
      expect(u.gender).to eq "m"
    end

    it "remembers that they have not competed before on validation error" do
      visit "/users/sign_up"
      click_on "I have never competed in a WCA competition."
      click_button "Sign up"

      expect(page).to have_selector('#never-competed', visible: true)
    end
  end
end
