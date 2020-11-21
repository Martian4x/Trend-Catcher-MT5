//+------------------------------------------------------------------+
//|                                                 Trend-Catcher v2 |
//|                                                        Martian4x |
//|                                         http://www.martian4x.com |
//+------------------------------------------------------------------+

#property copyright "Martian4x"
#property link      "http://www.martian4x.com"
#property description "A dual moving average cross, RSI and Trend Moving Average with timer, new bar check, money management, trailing stop and break even stop"

/*
 Creative Commons Attribution-NonCommercial 3.0 Unported
 http://creativecommons.org/licenses/by-nc/3.0/

 You may use this file in your own personal projects. You
 may modify it if necessary. You may even share it, provided
 the copyright above is present. No commercial use permitted. 
*/

// #define EXPERT_MAGIC 1000

// Trade
#include <Martian4xLib\MTrade.mqh>
MCTrade MTrade; // Martian Library

// Price
#include <Martian4xLib\Price.mqh>
CBars Bar;

// Money management
#include <Martian4xLib\MoneyManagement.mqh>

// Trailing stops
#include <Martian4xLib\TrailingStops.mqh>
CTrailing Trail;

// Timer
#include <Martian4xLib\Timer.mqh>
CTimer Timer;
CNewBar NewBar;

// Indicators 
#include <Martian4xLib\Indicators.mqh>
CiMA FastMA;
CiMA SlowMA;
CiMA TrendMA;
CiRSI RSI;
CiADX ADX;

//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+
input int EXPERT_MAGIC = 1000;
input ulong Slippage = 3;
input bool TradeOnNewBar = true;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = true;
input double RiskPercent = 2;
input double FixedVolume = 0.1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLoss = 500;
input int TakeProfit = 1000;

sinput string TS;		// Trailing Stop
input bool UseTrailingStop = true;
input int TrailingStop = 500;
input int MinimumProfit = 0;
input int Step = 0; 

sinput string BE;		// Break Even
input bool UseBreakEven = false;
input int BreakEvenProfit = 0;
input int LockProfit = 0;

sinput string FaMA;	// Fast MA
input int FastMAPeriod = 10;
input ENUM_MA_METHOD FastMAMethod = 0;
input int FastMAShift = 0;
input ENUM_APPLIED_PRICE FastMAPrice = PRICE_CLOSE;

sinput string SlMA;	// Slow MA
input int SlowMAPeriod = 20;
input ENUM_MA_METHOD SlowMAMethod = 0;
input int SlowMAShift = 0;
input ENUM_APPLIED_PRICE SlowMAPrice = PRICE_CLOSE;

sinput string TrMA;	// TrendMA
input int TrendMAPeriod = 50;
input ENUM_MA_METHOD TrendMAMethod = 0;
input int TrendMAShift = 0;
input ENUM_APPLIED_PRICE TrendMAPrice = PRICE_CLOSE;

sinput string RSIset;
enum RSILEVELLIST{
	RSI_50,
	RSI_UPPERLOWER
};
input RSILEVELLIST RSILevelSignalType = RSI_UPPERLOWER;
input int RSIPeriod = 10;
input ENUM_APPLIED_PRICE RSIPrice = PRICE_MEDIAN;

sinput string ADXset;
input bool UseADX = true;
input int ADXPeriod = 14;
input int ADXLevelLine = 20;

sinput string TI; 	// Timer
input bool UseTimer = false;
input int StartHour = 0;
input int StartMinute = 0;
input int EndHour = 0;
input int EndMinute = 0;
input bool UseLocalTime = false;

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

bool glBuyPlaced, glSellPlaced;
int glPositionTicket = 0;
string MASignal = "";
string TrendMASignal = "";
string RSISignal = "";
string ADXSignal = "";
string PositionSignal = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
	FastMA.Init(_Symbol,_Period,FastMAPeriod,FastMAShift,FastMAMethod,FastMAPrice);
	SlowMA.Init(_Symbol,_Period,SlowMAPeriod,SlowMAShift,SlowMAMethod,SlowMAPrice);
	TrendMA.Init(_Symbol,_Period,TrendMAPeriod,TrendMAShift,TrendMAMethod,TrendMAPrice);
	RSI.Init(_Symbol,_Period,RSIPeriod,RSIPrice);
	// ADX.Init(_Symbol,_Period,ADXPeriod);
	
	Trade.SetDeviationInPoints(Slippage);
	Trade.SetExpertMagicNumber(EXPERT_MAGIC);
   return(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
{

	// Check for new bar
	bool newBar = true;
	int barShift = 0;
	
	if(TradeOnNewBar == true) 
	{
		newBar = NewBar.CheckNewBar(_Symbol,_Period);
		barShift = 1;
	}
	
	// Timer
	bool timerOn = true;
	if(UseTimer == true)
	{
		timerOn = Timer.DailyTimer(StartHour,StartMinute,EndHour,EndMinute,UseLocalTime);
	}
	
	// Update prices
	Bar.Update(_Symbol,_Period);
	
	// Order placement
	if(newBar == true && timerOn == true)
	{
		// Money management
		double tradeSize;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,StopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);

      // MA Signal
		if(FastMA.Main(barShift+1) < SlowMA.Main(barShift+1) && FastMA.Main(barShift) > SlowMA.Main(barShift)){
			MASignal = "Buy";
		}else if(FastMA.Main(barShift+1) > SlowMA.Main(barShift+1) && FastMA.Main(barShift) < SlowMA.Main(barShift)){
			MASignal = "Sell";
		}

      // RSI Signal
		if(RSILevelSignalType == RSI_50){
			RSISignal = "";
			if(RSI.Main(barShift+1) > 50.0 && RSI.Main(barShift) < 50.0 ){
				RSISignal = "Sell";
			} else if(RSI.Main(barShift+1) < 50.0 && RSI.Main(barShift) > 50.0 ){
				RSISignal = "Buy";
			}
		} else {
			if(RSI.Main(barShift+1) < 30.0 && RSI.Main(barShift) > 30.0 ){
				RSISignal = "Buy";
			}else if(RSI.Main(barShift+1) > 70.0 && RSI.Main(barShift) < 70.0 ){
				RSISignal = "Sell";
			}
		}

      // TrendMA Signal
      TrendMASignal = "";
      if(SymbolInfoDouble(_Symbol,SYMBOL_ASK)>TrendMA.Main()){
         TrendMASignal = "Buy";
      }else if(SymbolInfoDouble(_Symbol,SYMBOL_BID)<TrendMA.Main()){
         TrendMASignal = "Sell";
      }

		// if(glBuyPlaced == false){
		// 	PositionSignal = "Buy";
		// }
		// Restrict the same previous trade type to place.
		// if(PositionType() != POSITION_TYPE_BUY){
		// 	LastSignal = "Buy";
		// }elseif(PositionType() != POSITION_TYPE_SELL){
		// 	LastSignal = "Sell";
		// }
		// if((ADX.Main(barShift+1) < ADXLevelLine && ADX.Main(barShift) > ADXLevelLine && UseADX == true) || UseADX == false){
		// 	ADXSignal = "Buy";
		// }
		
		// Open buy order
		if(glBuyPlaced == false && MASignal == "Buy" && RSISignal == "Buy" && TrendMASignal == "Buy")
		{
			// Close EA Sell Order
			if(PositionType() == POSITION_TYPE_SELL){
				MTrade.PositionClose(_Symbol);
			}

			glBuyPlaced = MTrade.Buy(tradeSize);
		
			if(glBuyPlaced == true)  
			{
				double openPrice = PositionOpenPrice(_Symbol);
				double buyStop = BuyStopLoss(_Symbol,StopLoss,openPrice);
				// Print("The Open Price: ", openPrice, "The Buy Stop: ", buyStop);
				if(buyStop > 0) AdjustBelowStopLevel(_Symbol,buyStop); 
				
				double buyProfit = BuyTakeProfit(_Symbol,TakeProfit,openPrice);
				if(buyProfit > 0) AdjustAboveStopLevel(_Symbol,buyProfit);
				
				// glPositionTicket = PositionGetInteger(POSITION_TICKET);
				if(buyStop > 0 || buyProfit > 0) MTrade.ModifyPosition(_Symbol,buyStop,buyProfit);
				glSellPlaced = false;
			} else {
				Print("The ",_Symbol, " order did not placed or selected");
			}
		}

		// if(glSellPlaced == false){
		// 	PositionSignal = "Sell";
		// }
		// Open sell order
		if(glSellPlaced == false && MASignal == "Sell" && RSISignal == "Sell" && TrendMASignal == "Sell")
		{
			// Close EA Buy Order
			if(PositionType() == POSITION_TYPE_BUY){
				MTrade.PositionClose(_Symbol);
			}

			glSellPlaced = MTrade.Sell(tradeSize);
			
			if(glSellPlaced == true)
			{
				double openPrice = PositionOpenPrice(_Symbol);
				
				double sellStop = SellStopLoss(_Symbol,StopLoss,openPrice);
				if(sellStop > 0) sellStop = AdjustAboveStopLevel(_Symbol,sellStop);
				Print("The Open Price: ", openPrice, "The sell Stop: ", sellStop);
				
				double sellProfit = SellTakeProfit(_Symbol,TakeProfit,openPrice);
				if(sellProfit > 0) sellProfit = AdjustBelowStopLevel(_Symbol,sellProfit);
				
				// glPositionTicket = PositionGetInteger(POSITION_TICKET);
				if(sellStop > 0 || sellProfit > 0) MTrade.ModifyPosition(_Symbol,sellStop,sellProfit);
				glBuyPlaced = false;
			}  else {
				Print("The ",_Symbol, " order did not placed or selected");
			}
		}
		
	} // Order placement end
	
	
	// Break even
	if(UseBreakEven == true && PositionType(_Symbol) != -1)
	{
		Trail.BreakEven(_Symbol,BreakEvenProfit,LockProfit);
	}
	
	// Trailing stop
	if(UseTrailingStop == true && PositionType(_Symbol) != -1)
	{
		glPositionTicket = PositionGetInteger(POSITION_TICKET);
		Trail.TrailingStop(glPositionTicket,TrailingStop,MinimumProfit,Step);
	}

	// if(PositionType() == POSITION_TYPE_SELL && ){
	// 	MTrade.PositionClose(_Symbol);
	// }

	Comment("MATradeSignal : ", MASignal,"| RSILevelSignalType : ",RSILevelSignalType , "| RSITradeSignal : ", RSISignal);


}


