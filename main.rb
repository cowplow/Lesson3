require 'rubygems'
require 'sinatra'
require 'pry'


use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'hashbrown'

BLACK_JACK = 21
DEALER_HITS_TO = 17
STARTING_CHIP_COUNT = 500 

helpers do

  def blackjack?(hand_value)
    hand_value == BLACK_JACK
  end

  def bust?(hand_value)
    hand_value > BLACK_JACK
  end

  def calculate_hand(hand)
    total = 0
    ace_count = 0

    hand.each do |card|
      if card[1] == 'Ace'
        total += 11
        ace_count += 1
      else
        total += (card[1].to_i == 0 ? 10 : card[1].to_i)
      end
    end

    ace_count.times do |a|
      break if total <= BLACK_JACK
      total -= 10
    end

    total
  end

  def pretty_cards(card)
    suit_names = { "D" => "Diamonds", "C" => "Clubs", "H" => "Hearts", "S" => "Spades" }
    "#{card[1]} of #{suit_names[card[0]]}"
  end

  def display_card(card, hidden=false)
    if hidden
      return "<img src='/images/cards/cover.jpg' class='card_image'/>"
    end

    suit_names = { "D" => "diamonds", "C" => "clubs", "H" => "hearts", "S" => "spades" }
    name = card[1].downcase
    file_name = "<img src='/images/cards/#{suit_names[card[0]]}_#{name}.jpg' class='card_image'/>"
  end

  def winner!(msg)
    @play_again = true
    @show_player_hand_buttons = false
    session[:chip_count] += (2 * session[:current_bet])
    session[:player_wins] += 1
    @success = "<strong>#{session[:player_name]} wins!</strong> #{msg} You win $#{session[:current_bet]}! You now have $#{session[:chip_count]}."
  end

  def loser!(msg)
    @play_again = true
    @show_player_hand_buttons = false
    session[:player_losses] += 1
    @error = "<strong>#{session[:player_name]} loses!</strong> #{msg} You lose $#{session[:current_bet]}. You now have $#{session[:chip_count]}."
  end

  def tie!(msg)
    @play_again = true
    @show_player_hand_buttons = false
    session[:chip_count] += session[:current_bet]
    session[:player_ties] += 1
    @stay = "<strong>It's a tie!</stong> #{msg} You now have $#{session[:chip_count]}."
  end
end

before do
  @show_player_hand_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect 'new_player'
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "A name is required.  Please try again."
    halt erb :new_player
  end
  session[:player_name] = params[:player_name].capitalize 
  session[:chip_count] = STARTING_CHIP_COUNT
  session[:player_wins] = 0
  session[:player_losses] = 0
  session[:player_ties] = 0
  session[:total_hands] = 0
  redirect '/bet'
end

get '/game' do
  session[:total_hands] += 1
  session[:turn] = "player"
  #create a deck and put it in session.
  SUITS = ['H', 'D', 'C', 'S']
  VALUES = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace']
  session[:deck] = SUITS.product(VALUES).shuffle!
  #deal cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  if blackjack?(calculate_hand(session[:player_cards]))
    redirect '/game/player/blackjack'
  end
  
  erb :game
end

post '/game/player/hit' do
  new_card = session[:deck].pop
  session[:player_cards] << new_card
  player_total = calculate_hand(session[:player_cards])
  if bust?(player_total)
     loser!("#{session[:player_name]} busted with #{player_total}")
     session[:turn] = "dealer"
  elsif blackjack?(player_total)
    redirect '/game/dealer'
  else
    @info = "You were dealt the " + pretty_cards(new_card)
  end

  erb :game, layout: false
end

get '/game/player/blackjack' do
  @blackjack = "Congratulations you were dealt a blackjack! You should stay ;)"

  erb :game
end

post '/game/player/stay' do
  @stay = "You chose to stay!"
  @show_player_hand_buttons = false

  redirect '/game/dealer'
end

get '/game/dealer' do
  @show_player_hand_buttons = false
  session[:turn] = "dealer"

  dealer_total = calculate_hand(session[:dealer_cards])
  if bust?(dealer_total)
    winner!("Dealer busted with #{dealer_total}.")
  elsif dealer_total >= DEALER_HITS_TO
    #dealer stays
    redirect '/game/compare'
  else
    #dealer hits
    @show_dealer_hit_button = true
  end

  erb :game, layout: false   
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  session[:show_player_hand_buttons] = false

  player_total = calculate_hand(session[:player_cards])
  dealer_total = calculate_hand(session[:dealer_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total} and dealer stayed at #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total} and dealer stayed at #{dealer_total}!")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}!")
  end

  erb :game, layout: false
end


get '/bet' do
  if session[:chip_count] <= 0
    @info = "You were out of chips.  We have resest your chip count to $500."
    session[:chip_count] = STARTING_CHIP_COUNT
  end
  erb :bet
end


post '/new_bet' do
  if params[:current_bet].empty? || params[:current_bet].to_i == 0
    @error = "#{params[:current_bet]} is not a valid amount. You must enter an amount more than $0."
    halt erb :bet
  elsif params[:current_bet].to_i > session[:chip_count]
    @error = "$#{params[:current_bet]} is too large. Bet must be less than or equal to $#{session[:chip_count]}."
    halt erb :bet
  end
  
  session[:current_bet] = params[:current_bet].to_i
  session[:chip_count] -= session[:current_bet]
  redirect '/game' 
end

post '/same_bet' do
  if session[:current_bet] > session[:chip_count]
    @error = "You don't have enough chips to make this bet.  Please enter a different  amount."
    redirect '/bet'
  else
    session[:chip_count] -= session[:current_bet]
    redirect '/game'
  end
end


get '/game_over' do
  erb :game_over
end







