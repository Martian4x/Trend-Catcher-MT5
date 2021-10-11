//+------------------------------------------------------------------+
//|                                                 Trend-Catcher v4 |
//|                                                        Martian4x |
//|                                         http://www.martian4x.com |
//+------------------------------------------------------------------+

#property copyright "Martian4x"
#property link "http://www.martian4x.com"
#property description "Based on BabyPips.com, you should know that the HLHB System simply aims to catch short-term forex trends. Huck-Loves-Her-Bucks the trend-catching A dual moving average cross, RSI, Trend Moving Average and ADX with timer, new bar check, money management, trailing stop and break even stop. Martian4x.com has added Trend MA to help filter falses."

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
CiAroon Aroon;

//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+
input int EXPERT_MAGIC = 14000;
input int INPUT_SET = 6848648;
input ulong Slippage = 3;
input bool TradeOnNewBar = false;

sinput string MM; // Money Management
input bool UseMoneyManagement = false;
input double RiskPercent = 2;
input double FixedVolume = 0.3;

sinput string SL; // Stop Loss & Take Profit
input int StopLoss = 100;
input int TakeProfit = 1000;

sinput string TS; // Trailing Stop
input bool UseTrailingStop = true;
input int TrailingStop = 500;
input int MinimumProfit = 0;
input int Step = 0;

sinput string FaMA; // Fast MA
input int FastMAPeriod = 10;
input ENUM_MA_METHOD FastMAMethod = MODE_EMA;
input int FastMAShift = 0;
input ENUM_APPLIED_PRICE FastMAPrice = PRICE_CLOSE;

sinput string SlMA; // Slow MA
input int SlowMAPeriod = 20;
input ENUM_MA_METHOD SlowMAMethod = MODE_EMA;
input int SlowMAShift = 0;
input ENUM_APPLIED_PRICE SlowMAPrice = PRICE_CLOSE;
input bool MASignalClear = true;

sinput string TrMA; // TrendMA
input bool UseTrendMA = true;
input int TrendMAPeriod = 50;
input ENUM_MA_METHOD TrendMAMethod = MODE_SMA;
input int TrendMAShift = 0;
input ENUM_APPLIED_PRICE TrendMAPrice = PRICE_CLOSE;

sinput string RSIset;
enum RSILEVELLIST
{
   RSI_50,
   RSI_UPPERLOWER
};
input RSILEVELLIST RSILevelSignalType = RSI_50;
input int RSIPeriod = 10;
input ENUM_APPLIED_PRICE RSIPrice = PRICE_MEDIAN;
input bool RSISignalClear = false;

input bool CloseTradeOnSignalInverse = true;

sinput string AroonSet;
input bool UseAroon = true;
input int AroonPeriod = 14;
// input int ADXLevelLine = 25;

sinput string BE; // Break Even
input bool UseBreakEven = false;
input int BreakEvenProfit = 0;
input int LockProfit = 0;

sinput string TI; // Timer
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
string AroonSignal = "";
string PositionSignal = "";
string EAInfo, AccountInfo, MoneyManagementInfo, SignalInfo, TradingInfo, FakeOutInfo, CurrentSignal, PositionInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   // Check if Automated Trade is allowed
   // Check if the Input Set Number is set
   if (INPUT_SET == NULL)
   {
      Alert("The Input Set Number is not set");
      return (0);
   }

   ENUM_ACCOUNT_TRADE_MODE account_type = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string trade_mode;
   switch (account_type)
   {
      case ACCOUNT_TRADE_MODE_DEMO:
         trade_mode = "DEMO";
         break;
      case ACCOUNT_TRADE_MODE_CONTEST:
         trade_mode = "CONTEST";
         break;
      default:
         trade_mode = "REAL";
         break;
   }

   EAInfo = "Name: " + MQLInfoString(MQL_PROGRAM_NAME) + ", MagicNumber: " + EXPERT_MAGIC + ", InputSet: " + INPUT_SET + ", MQL_TRADE_ALLOWED: " + MQLInfoInteger(MQL_TRADE_ALLOWED);
   AccountInfo = "TradeMode: " + trade_mode + ", Leverage: " + AccountInfoInteger(ACCOUNT_LEVERAGE) + ", Broker: " + AccountInfoString(ACCOUNT_COMPANY) + ", Server: " + AccountInfoString(ACCOUNT_SERVER) + ", AccountName: " + AccountInfoString(ACCOUNT_NAME);
   MoneyManagementInfo = "RiskPercent: " + RiskPercent + ", StopLoss: " + StopLoss + ", TakeProfit: " + TakeProfit + ", UseTrailingStop: " + UseTrailingStop + ", TrailingStop: " + TrailingStop;
   TradingInfo = "FastMAPeriod: " + FastMAPeriod + ", SlowMAPeriod: " + SlowMAPeriod + ", RSISignalType: " + (RSILEVELLIST)RSILevelSignalType + ", RSIPeriod: " + RSIPeriod + ", Slippage: " + Slippage + ", CloseTradeOnSignalInverse: " + CloseTradeOnSignalInverse;
   FakeOutInfo = "UseTrendMA: " + UseTrendMA + ", TrendMAPeriod: " + TrendMAPeriod + ", UseAroon: " + UseAroon + ", AroonPeriod: " + AroonPeriod;

   //
   FastMA.Init(_Symbol, _Period, FastMAPeriod, FastMAShift, FastMAMethod, FastMAPrice);
   SlowMA.Init(_Symbol, _Period, SlowMAPeriod, SlowMAShift, SlowMAMethod, SlowMAPrice);
   TrendMA.Init(_Symbol, _Period, TrendMAPeriod, TrendMAShift, TrendMAMethod, TrendMAPrice);
   RSI.Init(_Symbol, _Period, RSIPeriod, RSIPrice);
   Aroon.Init(_Symbol, PERIOD_H1, AroonPeriod);

   Trade.SetDeviationInPoints(Slippage);
   Trade.SetExpertMagicNumber(EXPERT_MAGIC);
   return (0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   bool newBar = true;
   int barShift = 0;
   if (TradeOnNewBar == true)
   {
      newBar = NewBar.CheckNewBar(_Symbol, _Period);
      barShift = 1;
   }

   // Timer
   bool timerOn = true;
   if (UseTimer == true)
   {
      timerOn = Timer.DailyTimer(StartHour, StartMinute, EndHour, EndMinute, UseLocalTime);
   }

   // Update prices
   Bar.Update(_Symbol, _Period);

   // Order placement
   if (newBar == true && timerOn == true)
   {
      // Money management
      double tradeSize;
      if(UseMoneyManagement == true)
         tradeSize = MoneyManagement(_Symbol, FixedVolume, RiskPercent, StopLoss);
      else
         tradeSize = VerifyVolume(_Symbol, FixedVolume);

      // MA Signal
      // if(MASignalClear==true)
      MASignal = "";
      if(FastMA.Main(barShift + 3) < SlowMA.Main(barShift + 3) && FastMA.Main(barShift) > SlowMA.Main(barShift))
      {
         MASignal = "Buy";
      }
      else if(FastMA.Main(barShift + 3) > SlowMA.Main(barShift + 3) && FastMA.Main(barShift) < SlowMA.Main(barShift))
      {
         MASignal = "Sell";
      }

      // RSI Signal
      if(RSILevelSignalType == RSI_50)
      {
         if(RSISignalClear==true) {// Clear || Hold the RSI Signal
            RSISignal = "";
         }
         if (RSI.Main(barShift + 1) > 50.0 && RSI.Main(barShift) < 50.0)
         {
            RSISignal = "Sell";
         }
         else if (RSI.Main(barShift + 1) < 50.0 && RSI.Main(barShift) > 50.0)
         {
            RSISignal = "Buy";
         }
      }
      else
      {
         if (RSI.Main(barShift + 1) < 30.0 && RSI.Main(barShift) > 30.0)
         {
            RSISignal = "Buy";
         }
         else if (RSI.Main(barShift + 1) > 70.0 && RSI.Main(barShift) < 70.0)
         {
            RSISignal = "Sell";
         }
      }

      // TrendMA Signal
      if((SymbolInfoDouble(_Symbol, SYMBOL_ASK) > TrendMA.Main() && UseTrendMA == true) || UseTrendMA == false)
      {
         TrendMASignal = "Buy";
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
      AroonSignal = "";
      if (Aroon.BullsAroonBuffer(barShift + 1) < Aroon.BearsAroonBuffer(barShift + 1) && Aroon.BullsAroonBuffer(barShift) > Aroon.BearsAroonBuffer(barShift) && Aroon.BullsAroonBuffer(barShift) > 80)
      {
         AroonSignal = "Buy";
      }

      // Open buy order
      // if (glBuyPlaced == false && MASignal == "Buy" == "Buy" && AroonSignal == "Buy")
      if (glBuyPlaced == false && TrendMASignal == "Buy" && RSISignal=="Buy" && AroonSignal == "Buy")
      {
         // Close EA Sell Order
         // if (PositionType() == POSITION_TYPE_SELL)
         if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            MTrade.PositionClose(_Symbol);
            glSellPlaced = false;
         }
         // Print("PositionType: ",PositionGetInteger(POSITION_TYPE));
         // Print("POSITION_TYPE_SELL: ",POSITION_TYPE_SELL);

         glBuyPlaced = MTrade.Buy(tradeSize);
         if(glBuyPlaced == true)
         {
            double openPrice = PositionOpenPrice(_Symbol);
            double buyStop = BuyStopLoss(_Symbol, StopLoss, openPrice);
            // Print("The Open Price: ", openPrice, "The Buy Stop: ", buyStop);
            if (buyStop > 0)
               AdjustBelowStopLevel(_Symbol, buyStop);

            double buyProfit = BuyTakeProfit(_Symbol, TakeProfit, openPrice);
            if (buyProfit > 0)
               AdjustAboveStopLevel(_Symbol, buyProfit);

            // glPositionTicket = PositionGetInteger(POSITION_TICKET);
            if (buyStop > 0 || buyProfit > 0)
               MTrade.ModifyPosition(_Symbol, buyStop, buyProfit);
            // Clear the signal after the signal triggered the trade.
            RSISignal = "";
         }
            else
         {
            Print("The ", _Symbol, " order did not placed or selected");
         }
      } // Position resume that was stopped with a stoploss
      // 1. Stopped by a stoploss not profit or trailling stop
      // 2. No Position currently open
      // 3. Moving Average and RSI are showing the same trend
      // 4. Price is beyond low/high of the stopped order

      if ((SymbolInfoDouble(_Symbol, SYMBOL_BID) < TrendMA.Main() && UseTrendMA == true) || UseTrendMA == false)
      {
         TrendMASignal = "Sell";
      }

      if (Aroon.BullsAroonBuffer(barShift + 1) > Aroon.BearsAroonBuffer(barShift + 1) && Aroon.BullsAroonBuffer(barShift) < Aroon.BearsAroonBuffer(barShift) && Aroon.BearsAroonBuffer(barShift) > 80)
      {
         AroonSignal = "Sell";
      }

      // if(glSellPlaced == false){
      // 	PositionSignal = "Sell";
      // }
      // Open sell order
      // if (glSellPlaced == false && MASignal == "Sell" && RSISignal == "Sell" && TrendMASignal == "Sell" && AroonSignal == "Sell")
      // if (glSellPlaced == false && MASignal == "Sell" && AroonSignal == "Sell")
      if (glSellPlaced == false && TrendMASignal == "Sell" && RSISignal == "Sell" && AroonSignal == "Sell")
      {
         // Close EA Buy Order
         if (PositionType() == POSITION_TYPE_BUY)
         {
            MTrade.PositionClose(_Symbol);
            glBuyPlaced = false;
         }
         Print("PositionType: ",PositionType());

         glSellPlaced = MTrade.Sell(tradeSize);

         if (glSellPlaced == true)
         {
            double openPrice = PositionOpenPrice(_Symbol);

            double sellStop = SellStopLoss(_Symbol, StopLoss, openPrice);
            if (sellStop > 0)
               sellStop = AdjustAboveStopLevel(_Symbol, sellStop);
            Print("The Open Price: ", openPrice, "The sell Stop: ", sellStop);

            double sellProfit = SellTakeProfit(_Symbol, TakeProfit, openPrice);
            if (sellProfit > 0)
               sellProfit = AdjustBelowStopLevel(_Symbol, sellProfit);

            // glPositionTicket = PositionGetInteger(POSITION_TICKET);
            if (sellStop > 0 || sellProfit > 0)
               MTrade.ModifyPosition(_Symbol, sellStop, sellProfit);
            // Clear the signal after the signal triggered the trade.
            RSISignal = ""; 
         }
         else
         {
            Print("The ", _Symbol, " order did not placed or selected");
         }
      }

   } // Order placement end

   
   // Close odder when moving averages crossover again.
   if(CloseTradeOnSignalInverse==true){
      if (PositionType() == POSITION_TYPE_BUY && AroonSignal == "Sell")
      {
         MTrade.PositionClose(_Symbol);
         Print("Buy Position closed by a AroonSignal Sell");
      } else if (PositionType() == POSITION_TYPE_SELL && AroonSignal == "Buy")
      {
         MTrade.PositionClose(_Symbol);
         Print("Sell Position closed by a AroonSignal Buy");
      }
   }

   // Clear Position gl variables
   if(PositionType()==-1){
      glSellPlaced = false;
      glBuyPlaced = false;
   }

   // Break even
   if (UseBreakEven == true && PositionType(_Symbol) != -1)
   {
      Trail.BreakEven(_Symbol, BreakEvenProfit, LockProfit);
   }

   // Trailing stop
   if (UseTrailingStop == true && PositionType(_Symbol) != -1)
   {
      glPositionTicket = PositionGetInteger(POSITION_TICKET);
      Trail.TrailingStop(glPositionTicket, TrailingStop, MinimumProfit, Step);
   }

   // if(PositionType() == POSITION_TYPE_SELL && ){
   // 	MTrade.PositionClose(_Symbol);
   // }

   // Comment("MATradeSignal : ", FastMA.Main(barShift+1),"| RSILevelSignalType : ",RSI.Main(barShift) , "| RSITradeSignal : ", RSISignal);
   // Chart Comment
   CurrentSignal = "MASignal: " + MASignal + ", RSISignal: " + RSISignal + ", TrendMASignal: " + TrendMASignal + ", AroonSignal: " + AroonSignal;
   PositionInfo = "BuyPlaced: " + glBuyPlaced + ", SellPlaced: " + glSellPlaced;
   Comment(EAInfo + "\n" + AccountInfo + "\n" + MoneyManagementInfo + "\n" + TradingInfo + "\n" + FakeOutInfo + "\n" + CurrentSignal + "\n" + PositionInfo);
}
