require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'hashbrown' 


SUITS = { "C" => "Clubs", "D" => "Diamonds", "H" => "Hearts", "S" => "Spades"}
VALUES = { "A" => 11, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "6" => 6, "7" => 7, "8" => 8, "9" => 9, "T" => 10, "J" => 10, "Q" => 10, "K" => 10} 
CARD_NAMES = { "A" => "Ace", "2" => "Two", "3" => "Three", "4" => "Four", "5" => "Five", "6" => "Six", "7" => "Seven", "8" => "Eight", "9" => "Nine", "T" => "Ten", "J" => "Jack", "Q" => "Queen", "K" => "King"}

helpers do

  def shuffle_deck
    deck = []
    SUITS.each do |suit|
      VALUES.each do |value|
        deck << "#{value[0]}#{suit[0]}"
      end
    end
    deck.shuffle!
  end

  def deal_one_card
    session[:deck].pop
  end

  def calculate_hand_value(hand)
    total = 0
    ace_count = 0

    hand.each do |card|
      if card[0] == "A"
        ace_count += 1
      end
      total += VALUES[card[0]]
    end

    ace_count.times do
      if bust?(total)
        total -= 10
      end
    end
    total
  end

  def bust?(hand_value)
    hand_value > 21
  end

  def blackjack?(hand_value)
    hand_value == 21
  end

end

get '/' do
  erb :set_name
end

post '/set_name' do
  session[:player_name] = params[:player_name].capitalize
  session[:chip_count] = 500
  session[:current_bet] = 50
  redirect '/bet'
end

get '/bet' do
  erb :set_bet
end

get '/home' do
  session[:deck] = shuffle_deck
  session[:player_cards] = []
  session[:dealer_cards] = []
  session[:player_cards] << deal_one_card
  session[:dealer_cards] << deal_one_card
  session[:player_cards] << deal_one_card
  session[:dealer_cards] << deal_one_card
  session[:stay] = false
  session[:dealer_active] = false
  session[:black_jack_or_bust] = blackjack?(calculate_hand_value(session[:player_cards])) ? "blackjack" : nil
  redirect '/game'
end

post '/new_bet' do
  cur_bet = params[:current_bet].to_i
  if cur_bet > session[:chip_count]
    redirect '/bet'
  else
    session[:current_bet] = cur_bet
    session[:chip_count] -= session[:current_bet]
    redirect '/home'
  end
end

post '/same_bet' do
  if session[:current_bet] > session[:chip_count]
    redirect '/bet'
  else
    session[:chip_count] -= session[:current_bet]
    redirect '/home'
  end
end

get '/game' do
  erb :game
end

post '/hit' do
  session[:player_cards] << deal_one_card
  if bust?(calculate_hand_value(session[:player_cards]))
    session[:black_jack_or_bust] = "bust"
  elsif blackjack?(calculate_hand_value(session[:player_cards]))
      session[:black_jack_or_bust] = "blackjack"
  end
  redirect :game
end

post '/stay' do
  session[:stay] = true
  redirect :game
end 