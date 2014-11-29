require 'rubygems'
require 'sinatra'
require 'pry'


use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret' 

helpers do

  def blackjack?(hand_value)
    hand_value == 21
  end

  def bust?(hand_value)
    hand_value > 21
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
      break if total <= 21
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

  def determine_winner(player_hand, dealer_hand)
    if bust?(player_hand)
      1  
    elsif bust?(dealer_hand)
      2
    elsif player_hand > dealer_hand
      3
    elsif player_hand < dealer_hand
      4
    else
      5
    end
  end
end

before do
  session[:hand_done] = false
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
  session[:player_name] = params[:player_name] 
  redirect '/game'
end

get '/game' do
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
    @success = "Congratulations. You have a blackjack"
    session[:player_turn_over] = true
  else
    session[:player_turn_over] = false
  end
  session[:dealer_active] = false
  session[:hand_done] = false
  
  erb :game
end

post '/game' do
  if params[:hit]
    new_card = session[:deck].pop
    session[:player_cards] << new_card
    hand = calculate_hand(session[:player_cards])
    if bust?(hand)
      @error = "Sorry. Looks like you busted."
      session[:player_turn_over] = true
    elsif blackjack?(hand)
      @success = "Congratulations. You have a blackjack!"
      session[:player_turn_over] = true
    else
      @info = "You were dealt the " + pretty_cards(new_card)
    end
  elsif params[:stay]
    @stay = "You chose to stay!"
    session[:player_turn_over] = true
  elsif !session[:dealer_active]
    @info = "The Dealer reveals their hole card...The " + pretty_cards(session[:dealer_cards][0])
    session[:dealer_active] = true
  elsif calculate_hand(session[:dealer_cards]) < 17 && !bust?(calculate_hand(session[:player_cards]))
    new_card = session[:deck].pop
    session[:dealer_cards] << new_card
    dealer_hand = calculate_hand(session[:dealer_cards])
    @info = "The Dealer draws the #{pretty_cards(new_card)}"
    if bust?(dealer_hand)
      @success = "Looks like the dealer busted!"
    elsif blackjack?(dealer_hand)
      @error = "Looks like the dealer got blackjack"
    end
  else
    outcome = determine_winner(calculate_hand(session[:player_cards]), calculate_hand(session[:dealer_cards]))
    case outcome
    when 1 then @error = "Sorry #{session[:player_name]}, you busted. The dealer wins this round"
    when 2 then @success = "You win this round!  The dealer busts"
    when 3 then @success = "You have the higher hand.  You win this round!"
    when 4 then @error = "The dealer has the higher hand.  You lose this round."
    when 5 then @stay = "Both hands are equal.  This round is a push!"
    end
    session[:hand_done] = true
  end

  erb :game
end





