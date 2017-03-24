require 'rails_helper'

RSpec.shared_examples 'media' do
  include_examples 'titleable'

  before do
    allow_any_instance_of(Feed).to receive(:follow)
    allow_any_instance_of(Feed).to receive(:unfollow)
  end

  # Columns which are mandatory for all media
  it { should have_db_column(:slug).of_type(:string) }
  it { should have_db_column(:abbreviated_titles).of_type(:string) }
  it { should have_db_column(:average_rating).of_type(:decimal) }
  it { should have_db_column(:rating_frequencies).of_type(:hstore) }
  it { should have_db_column(:start_date).of_type(:date) }
  it { should have_db_column(:end_date).of_type(:date) }
  it { should have_and_belong_to_many(:genres) }
  it { should have_many(:castings) }
  it { should have_many(:library_entries) }
  # Methods used for the magic
  it { should respond_to(:slug_candidates) }
  it { should respond_to(:progress_limit) }
  it { should delegate_method(:year).to(:start_date) }
  it 'should ensure rating is within 0..100' do
    should validate_numericality_of(:average_rating)
      .is_less_than_or_equal_to(100)
      .is_greater_than(0)
  end

  describe '#run_length' do
    context 'with a start date' do
      it 'should return the period from start_date to end_date' do
        subject.start_date = 6.months.ago.to_date
        subject.end_date = 3.months.ago.to_date
        expect(subject.run_length).to be_within(5).of(90) # 90 days = 3 months
      end
    end
    context 'without a start date' do
      it 'should return nil' do
        subject.start_date = nil
        subject.end_date = 3.months.ago.to_date
        expect(subject.run_length).to be_nil
      end
    end
    context 'without an end date' do
      it 'should return the period from start_date to today' do
        subject.start_date = 2.months.ago.to_date
        subject.end_date = nil
        expect(subject.run_length).to be_within(5).of(60) # 60 days = 2 months
      end
    end
  end

  describe '#calculate_rating_frequencies' do
    context 'with no library entries' do
      it 'should return a Hash of zeroes' do
        subject.save!
        freqs = subject.calculate_rating_frequencies
        expect(freqs).to include(2)
        expect(freqs).to include(7)
        expect(freqs).to include(13)
        expect(freqs).to include(17)
        expect(freqs.values).to all(eq(0))
      end
    end
    context 'with a couple library entries' do
      it 'should return the count of each rating in a Hash' do
        subject.save!
        3.times { create(:library_entry, media: subject, rating: 3) }
        freqs = subject.calculate_rating_frequencies
        expect(freqs[3]).to eq(3)
      end
    end
  end

  describe '#decrement_rating_frequency' do
    it 'should decrement the rating frequency' do
      subject.rating_frequencies['3'] = 5
      subject.save!
      subject.decrement_rating_frequency('3')
      subject.reload
      expect(subject.rating_frequencies['3']).to eq('4')
    end
  end

  describe '#increment_rating_frequency' do
    it 'should increment the rating frequency' do
      subject.rating_frequencies['3'] = 5
      subject.save!
      subject.increment_rating_frequency('3')
      subject.reload
      expect(subject.rating_frequencies['3']).to eq('6')
    end
    context 'without a pre-existing value' do
      it 'should assume zero' do
        subject.save!
        subject.increment_rating_frequency('3')
        subject.reload
        expect(subject.rating_frequencies['3']).to eq('1')
      end
    end
  end

  describe '#posts_feed' do
    it 'returns a posts feed for the media' do
      expect(subject.posts_feed)
        .to eq(Feed.media_posts(described_class, subject.id))
    end
  end

  describe '#media_feed' do
    it 'returns a media feed for the media' do
      expect(subject.media_feed)
        .to eq(Feed.media_media(described_class, subject.id))
    end
  end

  describe '#aggregated_feed' do
    it 'returns a general aggregated feed for the media' do
      expect(subject.aggregated_feed)
        .to eq(Feed.media_aggr(described_class, subject.id))
    end
  end

  describe '#posts_aggregated_feed' do
    it 'returns a posts aggregated feed for the media' do
      expect(subject.posts_aggregated_feed)
        .to eq(Feed.media_posts_aggr(described_class, subject.id))
    end
  end

  describe '#media_aggregated_feed' do
    it 'returns a media aggregated feed for the media' do
      expect(subject.media_aggregated_feed)
        .to eq(Feed.media_media_aggr(described_class, subject.id))
    end
  end

  describe 'after creating' do
    context 'setting up media feed' do
      let(:aggregated_feed) { double(:feed).as_null_object }

      before do
        allow(subject).to receive(:aggregated_feed).and_return(aggregated_feed)
      end

      it 'sets the aggregated feed to follow the posts feed' do
        expect(subject.aggregated_feed)
          .to receive(:follow).with(subject.posts_feed)
        subject.save!
      end

      it 'sets the aggregated feed to follow the media feed' do
        expect(subject.aggregated_feed)
          .to receive(:follow).with(subject.media_feed)
        subject.save!
      end
    end

    it 'sets the aggregated posts feed to follow the posts feed' do
      expect(subject.posts_aggregated_feed)
        .to receive(:follow).with(subject.posts_feed)
      subject.save!
    end

    it 'sets the aggregated media feed to follow the media feed' do
      expect(subject.media_aggregated_feed)
        .to receive(:follow).with(subject.media_feed)
      subject.save!
    end
  end
end
