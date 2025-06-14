//+------------------------------------------------------------------+
//| AdvancedTradingEA.mq5 - Enhanced Expert Advisor                  |
//+------------------------------------------------------------------+
#property copyright "Developed for Price Action Trading Course - Enhanced Version"
#property link      "Phone number: +989191191387"
#property version   "6.3"
#property description "Enhanced EA with Pitchfork, Schiff Pitchfork, Market Flows, Psychological Patterns, and Advanced Risk Management."

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double RiskPercent = 1.0;          // Risk per Trade (% of Account Balance)
input int Slippage = 3;                  // Slippage (pips)
input int MagicNumber = 19019;           // Magic Number
input double RiskRewardRatio = 3.0;      // Risk:Reward Ratio (1:3)
input int MaxOpenOrders = 5;             // Max Simultaneous Orders
input bool UseTrailingStop = true;       // Enable Trailing Stop
input double TrailingStopPips = 20.0;    // Trailing Stop (pips)
input bool RestrictTradingHours = false; // Restrict Trading Hours
input int StartTradingHour = 8;          // Start Trading Hour (UTC)
input int EndTradingHour = 18;           // End Trading Hour (UTC)
input double CandleTimeOffset = 10.0;    // Candle Time Text Offset (pips)
input bool EnableSignalArrows = true;    // Enable Signal Arrows on Chart
input bool EnableVonRestorffDetection = true; // Enable Von Restorff Effect Detection
input int ADXPeriod = 14;                // ADX Period for Market Flow Analysis
input int BBPeriod = 20;                 // Bollinger Bands Period
input double BBDeviation = 2.0;          // Bollinger Bands Deviation
input int NewtonBars = 30;               // Bars for Newtonian Extrapolation
input bool UseMultiplePitchforks = true; // Enable Multiple Pitchforks
input bool EnableHookDetection = true;   // Enable Hook Pattern Detection
input bool UseSchiffPitchfork = true;    // Enable Schiff Pitchfork Analysis

// Fractal-Fibonacci
input int FractalMajor_FF = 5;           // Major Fractal Period
input int FractalMinor_FF = 3;           // Minor Fractal Period
input int ATRPeriod_FF = 14;             // ATR Period
input double ZoneOffsetPips_FF = 10.0;   // Zone Offset (pips)
input double FibRetraceLevel_FF = 0.618; // Fibonacci Retracement Level
input double FibExtTarget_FF = 1.618;    // Fibonacci Extension Target
input int ManipHybridBars_FF = 3;        // Hybrid Bars for Manipulation
input int StandingBarsMin_FF = 10;       // Min Standing Bars
input double ManipStopOffsetPips_FF = 5.0; // Manipulation Stop Offset
input double StopLossRatio = 0.236;      // Stop Loss Ratio based on range
input double TolerancePips = 2;          // Tolerance in pips for zones

// OmniConfluence
input int FractalMajor_Omni = 5;         // Omni Major Fractal
input int FractalMinor_Omni = 3;         // Omni Minor Fractal
input int ATRPeriod_Omni = 14;           // Omni ATR Period
input double FibManipRetrace_Omni = 0.618; // Omni Fibonacci Retracement
input double FibManipExtTarget_Omni = 1.618; // Omni Fibonacci Extension
input int ZoneLen_Omni = 100;            // Omni Zone Length
input int MinorPendulumPeriod_Omni = 3;  // Omni Minor Pendulum Period
input int EMATrend_Omni = 34;            // Omni EMA Trend Period
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4; // Higher Timeframe
input int VolumeProfilePeriod = 20;      // Volume Profile Period
input int DynFreqLookback = 20;          // Dynamic Frequency Lookback

// Volatility and Flow
input double VolatilityThreshold = 1.5;  // Volatility Threshold (ATR Multiplier)
input int MemoryWindowBars = 50;         // Memory Window (bars)
input int SmoothFlowBars = 10;           // Smooth Flow Bars

// Trend Filter
input bool EnableMtfTrendFilter = true;  // Enable MTF Trend Filter
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H1; // Timeframe for trend detection
input int EMAPeriod = 50;                // Period for EMA in trend filter

// Trade Management
input int PartialClosePoints = 30;       // Points to close half of the trade
input int TrailingStartPoints = 50;      // Total points to start trailing stop
input int BreakEvenPoints = 20;          // Points to move SL to break even
input bool EnableRiskFree = true;        // Enable risk-free after partial close

// New Features
input int MinFreqTouch = 4;              // Minimum touches for frequency line validation
input double MinScoreThreshold = 4.0;    // Minimum signal score for entry
input bool EnableBandwagonDetection = true; // Enable Bandwagon Effect Detection

// Hook Signal Enhancements
input double HookLotMultiplier = 1.5;    // Lot Multiplier for Hook Signal
input double HookTPMultiplier = 1.5;     // TP Multiplier for Hook
input double HookTrailingStopPips = 15.0;// Trailing Stop for Hook
input double RequiredHookScore = 6.0;    // Minimum Score for Hook

//+------------------------------------------------------------------+
//| Global Structures and Variables                                  |
//+------------------------------------------------------------------+
struct PitchforkPoints
{
   datetime   time1;
   double     price1;
   datetime   time2;
   double     price2;
   datetime   time3;
   double     price3;
};

struct Zone { 
   datetime t; 
   double price; 
   bool flipped; 
   int lastTouched;    // Bar index of last touch
   bool isActive;      // Based on memory window
   int touches;        // How many times price touched
};
Zone DemandZone = {0, 0, false, 0, false, 0}, SupplyZone = {0, 0, false, 0, false, 0};
Zone demand2 = {0, 0, false, 0, false, 0}, supply2 = {0, 0, false, 0, false, 0};
bool foundD2 = false, foundS2 = false;

struct MultiFreqLine {
   datetime t1, t2;
   double p1, p2;
   int touches;
   bool isActive;
   string freqType; // "Primary", "Secondary", etc.
};
MultiFreqLine allFreqLines[20];
int allFreqLineCount = 0;

struct TradeStat {
   datetime t;
   string signalType;
   double entry;
   double sl, tp;
   bool win;
};
TradeStat stats[500];
int statCount = 0;

struct SignalStat {
   string signalType;
   bool win;
   double rrAchieved;
   datetime entryTime;
   double entryPrice;
   datetime exitTime;
   double exitPrice;
};
SignalStat signalStats[100];
int signalStatCount = 0;

enum Quality { LOW, MEDIUM, HIGH };
Quality fibQuality = LOW;
int fibTouchCount = 0, fibBreakCount = 0;

bool tookBuy = false, tookSell = false;
bool aggressiveTaken = false, conservativeTaken = false;

datetime pivHighTime[2], pivLowTime[2];
double pivHighVal[2], pivLowVal[2];
bool pivReady = false, pivLowReady = false;

int pivotHighs[10], pivotLows[10], pCountH = 0, pCountL = 0;

bool svReady = false; datetime svT1, svT2; double svP1, svP2;
bool manipulationDetected = false; double manipLevel = 0; int hybridCount = 0;
bool vonRestorffDetected = false;
bool bandwagonDetected = false;
bool isStanding = false; int standingCount = 0;
bool highVolDetected = false, lowVolFlow = false;
datetime mpT[3]; double mpP[3]; bool mpReady = false;
bool expPivotReady = false; datetime e0, e1, e2; double ep0, ep1, ep2;
bool ofReady = false; datetime ofT1, ofT2; double ofP1, ofP2;
double pitchCLevel = 0;

double fibTimeSeqInternal[5] = {1, 2, 3, 5, 8};
double atrCurrent, atrPrevious;
bool isSmoothFlow = false;
double emaTrend, emaPrevious;
int signal = 0; // 1 for buy, -1 for sell, 0 for no signal
datetime lastCandleTime = 0;
double pitchforkMedian = 0, pitchforkUpper = 0, pitchforkLower = 0;
double schiffMedian = 0, schiffUpper = 0, schiffLower = 0;
double fibSquareLevel, newtonProjectionLevel;
double adxCurrent = 0;
double adxValue = 0;
double bbUpper, bbLower, bbMiddle;
double newtonProjection = 0;

bool pitchforkBuyCondition = false;
bool pitchforkSellCondition = false;

// Indicator Handles
int atrHandle;
int maHandle;
int adxHandle;
int bbHandle;
int smaVolumeHandle; // Handle for SMA volume

//+------------------------------------------------------------------+
//| Utility Functions for Entry                                      |
//+------------------------------------------------------------------+
bool IsBullishFractal(int index)
{
   if(index < 1 || index > (Bars(_Symbol, _Period) - 2))
      return(false);
   double h0 = iHigh(_Symbol, _Period, index);
   double h1 = iHigh(_Symbol, _Period, index + 1);
   double h_1 = iHigh(_Symbol, _Period, index - 1);
   return (h0 > h1 && h0 > h_1);
}

bool IsBearishFractal(int index)
{
   if(index < 1 || index > (Bars(_Symbol, _Period) - 2))
      return(false);
   double l0 = iLow(_Symbol, _Period, index);
   double l1 = iLow(_Symbol, _Period, index + 1);
   double l_1 = iLow(_Symbol, _Period, index - 1);
   return (l0 < l1 && l0 < l_1);
}

int IsHybridBar(int index)
{
   if(index < 1 || index > (Bars(_Symbol, _Period) - 2))
      return(0);
   bool bullishFractal = IsBullishFractal(index);
   bool bearishFractal = IsBearishFractal(index);
   double body = iClose(_Symbol, _Period, index) - iOpen(_Symbol, _Period, index);
   double upperWick = iHigh(_Symbol, _Period, index) - MathMax(iOpen(_Symbol, _Period, index), iClose(_Symbol, _Period, index));
   double lowerWick = MathMin(iOpen(_Symbol, _Period, index), iClose(_Symbol, _Period, index)) - iLow(_Symbol, _Period, index);
   double pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double wickThreshold = 10 * pip;
   
   if(bullishFractal && body > 0 && lowerWick >= wickThreshold)
      return(1);
   if(bearishFractal && body < 0 && upperWick >= wickThreshold)
      return(-1);
   
   return(0);
}

bool DynamicFrequencyBreakout(double levelPrice, int direction)
{
   MqlRates prevBar[];
   ArraySetAsSeries(prevBar, true);
   CopyRates(_Symbol, _Period, 1, 1, prevBar);
   double closePrev = prevBar[0].close;
   double closeCurr = iClose(_Symbol, _Period, 0);
   
   if(direction == +1)
   {
      if(closePrev <= levelPrice && closeCurr > levelPrice)
         return(true);
   }
   else if(direction == -1)
   {
      if(closePrev >= levelPrice && closeCurr < levelPrice)
         return(true);
   }
   return(false);
}

bool IsAtPitchforkEdge(const PitchforkPoints &pf, int edgeType, double tolerancePx)
{
   datetime t1, t3;
   double p1, p3;
   if(edgeType == +1)
   {
      t1 = pf.time1;    p1 = pf.price1;
      t3 = pf.time3;    p3 = pf.price3;
   }
   else
   {
      t1 = pf.time1;    p1 = pf.price1;
      t3 = pf.time3;    p3 = pf.price3;
   }
   double slope = (p3 - p1) / (double)(t3 - t1);
   datetime nowTime = iTime(_Symbol, _Period, 0);
   double linePrice = p1 + slope * (double)(nowTime - t1);
   double diff = MathAbs(iClose(_Symbol, _Period, 0) - linePrice);
   return (diff <= tolerancePx);
}

bool InSupplyDemandZone(double zoneHigh, double zoneLow)
{
   double price = iClose(_Symbol, _Period, 0);
   return (price <= zoneHigh && price >= zoneLow);
}

ulong PlaceBuyOrderWithSLTP(double slPips, double tpPips)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl = ask - slPips * point;
   double stopLossPips = (ask - sl) / point;
   double lotSize = CalculateDynamicLotSize(stopLossPips);
   double tp = ask + tpPips * point;
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lotSize;
   request.type     = ORDER_TYPE_BUY;
   request.price    = ask;
   request.sl       = sl;
   request.tp       = tp;
   request.deviation= Slippage; // Use input Slippage
   request.magic    = MagicNumber;
   request.comment  = "BuyEntry";
   
   if(!OrderSend(request, result))
   {
      PrintFormat("Error Opening Buy Order: %d - %s", result.retcode, result.comment);
      return(ulong) -1;
   }
   return(result.order);
}

ulong PlaceSellOrderWithSLTP(double slPips, double tpPips)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl = bid + slPips * point;
   double stopLossPips = (sl - bid) / point;
   double lotSize = CalculateDynamicLotSize(stopLossPips);
   double tp = bid - tpPips * point;
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lotSize;
   request.type     = ORDER_TYPE_SELL;
   request.price    = bid;
   request.sl       = sl;
   request.tp       = tp;
   request.deviation= Slippage; // Use input Slippage
   request.magic    = MagicNumber;
   request.comment  = "SellEntry";
   
   if(!OrderSend(request, result))
   {
      PrintFormat("Error Opening Sell Order: %d - %s", result.retcode, result.comment);
      return(ulong) -1;
   }
   return(result.order);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("AdvancedTradingEA v6.3 Initialized with Enhanced Features");

   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod_FF);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return INIT_FAILED;
   }

   if(EnableMtfTrendFilter)
   {
      maHandle = iMA(_Symbol, HigherTF, EMATrend_Omni, 0, MODE_EMA, PRICE_CLOSE);
      if(maHandle == INVALID_HANDLE)
      {
         Print("Failed to create MA handle");
         return INIT_FAILED;
      }

      adxHandle = iADX(_Symbol, HigherTF, ADXPeriod);
      if(adxHandle == INVALID_HANDLE)
      {
         Print("Failed to create ADX handle");
         return INIT_FAILED;
      }
   }

   bbHandle = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands handle");
      return INIT_FAILED;
   }

   smaVolumeHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, VOLUME_TICK); // SMA volume handle with period 20
   if(smaVolumeHandle == INVALID_HANDLE)
   {
      Print("Failed to create SMA volume handle");
      return INIT_FAILED;
   }

   ObjectsDeleteAll(0, "EA_"); // Delete only EA objects
   lastCandleTime = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "EA_"); // Delete only EA objects
   IndicatorRelease(atrHandle);
   IndicatorRelease(maHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(bbHandle);
   IndicatorRelease(smaVolumeHandle); // Release SMA volume handle
   Print("Deinit Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(iBars(_Symbol, PERIOD_CURRENT) < MemoryWindowBars + FractalMajor_FF)
   {
      Print("Insufficient bars: ", iBars(_Symbol, PERIOD_CURRENT));
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(lastCandleTime != iTime(_Symbol, PERIOD_CURRENT, 0))
   {
      lastCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);

      double atrBuffer[2];
      if(CopyBuffer(atrHandle, 0, 1, 2, atrBuffer) == 2)
      {
         atrCurrent = atrBuffer[0];
         atrPrevious = atrBuffer[1];
      }
      else
      {
         Print("Failed to copy ATR buffer");
         return;
      }

      if(EnableMtfTrendFilter)
      {
         double maBuffer[2];
         if(CopyBuffer(maHandle, 0, 1, 2, maBuffer) == 2)
         {
            emaTrend = maBuffer[0];
            emaPrevious = maBuffer[1];
         }
         else
         {
            Print("Failed to copy MA buffer");
            return;
         }

         double adxBuffer[1];
         if(CopyBuffer(adxHandle, 0, 1, 1, adxBuffer) == 1)
         {
            adxCurrent = adxBuffer[0];
         }
         else
         {
            Print("Failed to copy ADX buffer");
            return;
         }

         signal = (adxCurrent > 25) ? (emaTrend > emaPrevious ? 1 : (emaTrend < emaPrevious ? -1 : 0)) : 0;
      }

      // Define supply and demand zones dynamically
      ScanZones();
      double demandHigh = DemandZone.price + ZoneOffsetPips_FF * Point();
      double demandLow = DemandZone.price - ZoneOffsetPips_FF * Point();
      double supplyHigh = SupplyZone.price + ZoneOffsetPips_FF * Point();
      double supplyLow = SupplyZone.price - ZoneOffsetPips_FF * Point();

      // Pitchfork logic
      PitchforkPoints pf;
      pf.time1 = iTime(_Symbol, _Period, 50);
      pf.price1 = iHigh(_Symbol, _Period, 50);
      pf.time2 = iTime(_Symbol, _Period, 40);
      pf.price2 = iLow(_Symbol, _Period, 40);
      pf.time3 = iTime(_Symbol, _Period, 30);
      pf.price3 = iHigh(_Symbol, _Period, 30);
      double tolerancePx = 5 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      // Entry conditions for Buy
      double freqLevelBuy = demandHigh;
      int hybridType = IsHybridBar(1);
      if(InSupplyDemandZone(demandHigh, demandLow) && 
         DynamicFrequencyBreakout(freqLevelBuy, +1) && 
         hybridType == 1 && 
         CountOpenOrders() < MaxOpenOrders)
      {
         PlaceBuyOrderWithSLTP(20.0, 40.0);
         tookBuy = true;
      }

      // Entry conditions for Sell
      double freqLevelSell = supplyLow;
      if(InSupplyDemandZone(supplyHigh, supplyLow) && 
         DynamicFrequencyBreakout(freqLevelSell, -1) && 
         hybridType == -1 && 
         CountOpenOrders() < MaxOpenOrders)
      {
         PlaceSellOrderWithSLTP(20.0, 40.0);
         tookSell = true;
      }

      // Pitchfork edge trading
      if(IsAtPitchforkEdge(pf, +1, tolerancePx) && CountOpenOrders() < MaxOpenOrders)
      {
         PlaceSellOrderWithSLTP(20.0, 40.0);
         tookSell = true;
      }
      else if(IsAtPitchforkEdge(pf, -1, tolerancePx) && CountOpenOrders() < MaxOpenOrders)
      {
         PlaceBuyOrderWithSLTP(20.0, 40.0);
         tookBuy = true;
      }

      // Existing logic
      bool isVolatile = CheckVolatilityAsymmetry();
      isSmoothFlow = CheckSmoothFlow();
      vonRestorffDetected = EnableVonRestorffDetection ? DetectVonRestorffEffect(1) : false;
      bandwagonDetected = EnableBandwagonDetection ? DetectBandwagonEffect(1) : false;

      AnalyzeMarketFlow();
      newtonProjectionLevel = CalculateNewtonianProjection();
      if(UseMultiplePitchforks) CalculateMultiplePitchforks();
      if(UseSchiffPitchfork) CalculateSchiffPitchfork();

      ScanZones2();
      ScanPivots();
      ScanMinorPivots();
      DetectZoneFlips(bid);
      DetectZoneFlips2(bid);
      UpdateFibZoneQuality(bid);

      if(allFreqLineCount < 20)
      {
         AddMultiFreqLine(DemandZone.t, DemandZone.price, SupplyZone.t, SupplyZone.price, "Primary");
      }
      ValidateFreqLines(iClose(_Symbol, PERIOD_CURRENT, 0));
      int flowType = DetectFlowType();
      UpdatePivots();

      if(vonRestorffDetected || bandwagonDetected)
      {
         BuildMinorPendulum();
         BuildMinorInwardParallel();
      }

      DetectVolatility(1);
      DetectManipulation();
      DetectExpandingPivot(1);
      BuildFibSquareField();
      BuildSilhouette();
      BuildOutwardFrequency();
      CalculatePitchfork();
      fibSquareLevel = BuildOmniFibSquareField();

      bool hybrid = IsHybridBar(1) != 0;
      if(hybrid) DrawHybridBarMarker(1);
      bool fsBuy = DetectFailureSwing(1, 0);
      bool fsSell = DetectFailureSwing(1, 1);
      bool flow = DetectFlow(1);
      int fq = GetFibQuality();
      DetectFlow2(1);
      bool fs2 = DetectFailureSwing2(1);
      bool freqValid = (allFreqLineCount > 0 && allFreqLines[0].touches >= MinFreqTouch);
      bool volumeConfirm = IsVolumeCluster(1, VolumeProfilePeriod, 1.5);
      double buyScore = ComputeSignalScore(fsBuy, hybrid, freqValid, DemandZone.touches, flowType, volumeConfirm);
      double sellScore = ComputeSignalScore(fsSell, hybrid, freqValid, SupplyZone.touches, flowType, volumeConfirm);

      DetectFrequencyBreakout(bid);

      if(isSmoothFlow && isVolatile && !manipulationDetected && CountOpenOrders() < MaxOpenOrders)
      {
         EntryLogic(ask, hybrid, fsBuy, fsSell, flow, fq, buyScore, sellScore, flowType);
         bool triple = CheckTripleConfluence(bid);
         if(triple && (hybrid || fs2 || vonRestorffDetected || bandwagonDetected))
         {
            if(!isStanding && fibQuality >= MEDIUM && !aggressiveTaken && bid <= EntryLevel2())
            {
               PlaceOrder2(ORDER_TYPE_SELL, "AggressiveTriConfl");
               aggressiveTaken = true;
            }
            if(fibQuality == HIGH && !conservativeTaken && fs2)
            {
               PlaceOrder2(ORDER_TYPE_SELL, "ConservativeTriConfl");
               conservativeTaken = true;
            }
         }
         AutomatedTradingLogic(ask, hybrid, fsBuy, fsSell, flow, fq, buyScore, sellScore, flowType);
         if(IsTripleIntersectionConfirmed())
         {
            ExecuteTripleIntersectionTrade();
            DrawTripleIntersectionMarker();
         }
      }

      ManageOpenOrders();

      DrawObjects();
      if(EnableSignalArrows) DrawSignalArrows(hybrid, fsBuy, fsSell);
      DrawAllFreqLines();
      DrawSignalConfidence(DemandZone, buyScore, true);
      DrawSignalConfidence(SupplyZone, sellScore, false);
      if(flowType == 0) DrawNoiseWarning();
      DrawStatOverlay();
      AnalyzeSignalAccuracy();
      DrawSignalStats(); // Display signal statistics
   }

   DisplayCandleTimeRemaining();
}

//+------------------------------------------------------------------+
//| Count Open Orders                                                |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            (PositionGetInteger(POSITION_MAGIC) == MagicNumber || PositionGetInteger(POSITION_MAGIC) == MagicNumber + 1))
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Entry Logic                                                      |
//+------------------------------------------------------------------+
void EntryLogic(double price, bool hybrid, bool fsBuy, bool fsSell, bool flow, int fq, double buyScore, double sellScore, int flowType)
{
   if(RestrictTradingHours && !IsTradingTimeAllowed()) return;

   double buyL = DemandZone.price + (SupplyZone.price - DemandZone.price) * FibRetraceLevel_FF;
   double sellL = SupplyZone.price - (SupplyZone.price - DemandZone.price) * FibRetraceLevel_FF;
   bool zBuy = price >= DemandZone.price && price <= SupplyZone.price;
   bool zSell = price >= DemandZone.price && price <= SupplyZone.price;
   double stopLossPips = atrCurrent / Point() * 2.0;
   double takeProfitPips = stopLossPips * RiskRewardRatio;
   bool pitchforkBuy = UseSchiffPitchfork ? (price > schiffMedian && price < schiffUpper) : (price > pitchforkMedian && price < pitchforkUpper);
   bool pitchforkSell = UseSchiffPitchfork ? (price < schiffMedian && price > schiffLower) : (price < pitchforkMedian && price > pitchforkLower);
   bool hookBuy = EnableHookDetection ? DetectHook(1, 1) : false;
   bool hookSell = EnableHookDetection ? DetectHook(1, -1) : false;

   if(signal == 1 && zBuy && flow && (hybrid || fsBuy || hookBuy) && fq >= MEDIUM && buyScore >= MinScoreThreshold && !tookBuy && price <= buyL && pitchforkBuy && flowType == 2 && IsBuySetup(price))
   {
      double sl = price - stopLossPips * Point();
      double tp = price + takeProfitPips * Point();
      trade.Buy(CalculateDynamicLotSize(stopLossPips), _Symbol, price, sl, tp, "Buy_FibZone_Hook_v6");
      if(signalStatCount < 100) LogSignalStat("Hook", false, (tp - price) / (price - sl), iTime(_Symbol, PERIOD_CURRENT, 0), price, 0, 0);
      tookBuy = true;
   }
   if(signal == -1 && zSell && flow && (hybrid || fsSell || hookSell) && fq >= MEDIUM && sellScore >= MinScoreThreshold && !tookSell && price >= sellL && pitchforkSell && flowType == 2 && IsSellSetup(price))
   {
      double sl = price + stopLossPips * Point();
      double tp = price - takeProfitPips * Point();
      trade.Sell(CalculateDynamicLotSize(stopLossPips), _Symbol, price, sl, tp, "Sell_FibZone_Hook_v6");
      if(signalStatCount < 100) LogSignalStat("Hook", false, (price - tp) / (sl - price), iTime(_Symbol, PERIOD_CURRENT, 0), price, 0, 0);
      tookSell = true;
   }
}

//+------------------------------------------------------------------+
//| Check Triple Confluence                                          |
//+------------------------------------------------------------------+
bool CheckTripleConfluence(double price)
{
   if(!svReady || !manipulationDetected) return false;

   double x = (double)iTime(_Symbol, PERIOD_CURRENT, 1);
   double t1 = (double)svT1;
   double t2 = (double)svT2;

   if(t2 == t1)
   {
      Print("Error: svT2 equals svT1, cannot compute silhouette line");
      return false;
   }

   double sil = svP1 + (svP2 - svP1) / (t2 - t1) * (x - t1);
   double ent = EntryLevel2();

   return (MathAbs(price - sil) <= ZoneOffsetPips_FF * Point() && MathAbs(price - ent) <= ZoneOffsetPips_FF * Point());
}

//+------------------------------------------------------------------+
//| Entry Level 2                                                    |
//+------------------------------------------------------------------+
double EntryLevel2()
{
   if(!manipulationDetected) return 0;
   return manipLevel - (manipLevel - demand2.price) * FibManipRetrace_Omni;
}

//+------------------------------------------------------------------+
//| Scan Pivots                                                      |
//+------------------------------------------------------------------+
void ScanPivots()
{
   int h = 0;
   pivReady = false;
   for(int i = FractalMajor_FF; i < ZoneLen_Omni && i < iBars(_Symbol, PERIOD_CURRENT) - FractalMajor_FF && h < 2; i++)
   {
      if(IsFractalHigh(i, FractalMajor_FF))
      {
         pivHighTime[h] = iTime(_Symbol, PERIOD_CURRENT, i);
         pivHighVal[h] = iHigh(_Symbol, PERIOD_CURRENT, i);
         h++;
      }
   }
   pivReady = (h == 2);
}

//+------------------------------------------------------------------+
//| Scan Minor Pivots                                                |
//+------------------------------------------------------------------+
void ScanMinorPivots()
{
   int l = 0;
   pivLowReady = false;
   for(int i = FractalMinor_FF; i < ZoneLen_Omni && i < iBars(_Symbol, PERIOD_CURRENT) - FractalMinor_FF && l < 2; i++)
   {
      if(IsFractalLow(i, FractalMinor_FF))
      {
         pivLowTime[l] = iTime(_Symbol, PERIOD_CURRENT, i);
         pivLowVal[l] = iLow(_Symbol, PERIOD_CURRENT, i);
         l++;
      }
   }
   pivLowReady = (l == 2);
}

//+------------------------------------------------------------------+
//| Detect Zone Flips                                                |
//+------------------------------------------------------------------+
void DetectZoneFlips(double price)
{
   if(!SupplyZone.flipped && price > SupplyZone.price + TolerancePips * Point())
   {
      SupplyZone.flipped = true;
      SupplyZone.touches++;
      if(SupplyZone.touches >= 2) SupplyZone.isActive = false; // Flip after 2 touches
   }
   if(!DemandZone.flipped && price < DemandZone.price - TolerancePips * Point())
   {
      DemandZone.flipped = true;
      DemandZone.touches++;
      if(DemandZone.touches >= 2) DemandZone.isActive = false; // Flip after 2 touches
   }
}

//+------------------------------------------------------------------+
//| Detect Secondary Zone Flips                                      |
//+------------------------------------------------------------------+
void DetectZoneFlips2(double price)
{
   if(foundD2 && !demand2.flipped && price < demand2.price - TolerancePips * Point())
   {
      demand2.flipped = true;
      demand2.touches++;
      if(demand2.touches >= 2) demand2.isActive = false; // Flip after 2 touches
   }
   if(foundS2 && !supply2.flipped && price > supply2.price + TolerancePips * Point())
   {
      supply2.flipped = true;
      supply2.touches++;
      if(supply2.touches >= 2) supply2.isActive = false; // Flip after 2 touches
   }
}

//+------------------------------------------------------------------+
//| Update Fibonacci Zone Quality                                    |
//+------------------------------------------------------------------+
void UpdateFibZoneQuality(double price)
{
   if(MathAbs(price - DemandZone.price) <= TolerancePips * Point()) fibTouchCount++;
   if(MathAbs(price - SupplyZone.price) <= TolerancePips * Point()) fibBreakCount++;
   if(fibBreakCount > 1) fibQuality = HIGH;
   else if(fibTouchCount > 1) fibQuality = MEDIUM;
   else fibQuality = LOW;
}

//+------------------------------------------------------------------+
//| Build Minor Pendulum                                             |
//+------------------------------------------------------------------+
void BuildMinorPendulum()
{
   int c = 0;
   for(int i = FractalMinor_Omni; i < ZoneLen_Omni && i < iBars(_Symbol, PERIOD_CURRENT) - FractalMinor_Omni && c < 3; i++)
   {
      if(IsFractalLow2(i, FractalMinor_Omni) && c < 2)
      {
         mpT[c] = iTime(_Symbol, PERIOD_CURRENT, i + 1);
         mpP[c] = iLow(_Symbol, PERIOD_CURRENT, i + 1);
         c++;
      }
      else if(IsFractalHigh2(i, FractalMinor_Omni) && c == 2)
      {
         mpT[2] = iTime(_Symbol, PERIOD_CURRENT, i + 1);
         mpP[2] = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
         c++;
      }
   }
   mpReady = (c == 3);
}

//+------------------------------------------------------------------+
//| Build Minor Inward Parallel                                      |
//+------------------------------------------------------------------+
void BuildMinorInwardParallel()
{
   if(!mpReady) return;
   double dx = (double)(mpT[1] - mpT[0]) / Period();
   double dy = mpP[1] - mpP[0];
   double slope = dy / dx;
   double intercept = mpP[0] - slope * ((double)mpT[0] / Period());
   e0 = mpT[0];
   ep0 = slope * ((double)mpT[0] / Period()) + intercept;
   e1 = mpT[1];
   ep1 = slope * ((double)mpT[1] / Period()) + intercept;
}

//+------------------------------------------------------------------+
//| Detect Volatility                                                |
//+------------------------------------------------------------------+
void DetectVolatility(int idx)
{
   double range = iHigh(_Symbol, PERIOD_CURRENT, idx) - iLow(_Symbol, PERIOD_CURRENT, idx);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, idx, 1, atr) == 1)
   {
      if(!highVolDetected && range > 2 * atr[0])
      {
         highVolDetected = true;
         ObjectCreate(0, "EA_VolSpike_" + IntegerToString(idx), OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, idx), iHigh(_Symbol, PERIOD_CURRENT, idx));
         ObjectSetString(0, "EA_VolSpike_" + IntegerToString(idx), OBJPROP_TEXT, "Volatility Spike");
         ObjectSetInteger(0, "EA_VolSpike_" + IntegerToString(idx), OBJPROP_COLOR, clrRed);
      }
      if(highVolDetected && !lowVolFlow && range < 0.5 * atr[0])
      {
         lowVolFlow = true;
         ObjectCreate(0, "EA_LowVolFlow_" + IntegerToString(idx), OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, idx), iLow(_Symbol, PERIOD_CURRENT, idx));
         ObjectSetString(0, "EA_LowVolFlow_" + IntegerToString(idx), OBJPROP_TEXT, "Low Volatility Flow");
         ObjectSetInteger(0, "EA_LowVolFlow_" + IntegerToString(idx), OBJPROP_COLOR, clrGreen);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Manipulation                                              |
//+------------------------------------------------------------------+
void DetectManipulation()
{
   if(!manipulationDetected && IsHybridBar(1) != 0 && ++hybridCount >= ManipHybridBars_FF)
   {
      manipulationDetected = true;
      manipLevel = supply2.price;
   }
}

//+------------------------------------------------------------------+
//| Calculate Pitchfork C                                            |
//+------------------------------------------------------------------+
void CalculatePitchforkC()
{
   if(pivReady && foundD2)
   {
      double dx = (double)(demand2.t - pivHighTime[1]) / Period();
      double dy = demand2.price - pivHighVal[1];
      double slope = dy / dx;
      double intercept = demand2.price - slope * ((double)demand2.t / Period());
      double tm = (double)TimeCurrent() / Period();
      pitchCLevel = slope * tm + intercept;
   }
}

//+------------------------------------------------------------------+
//| Detect Expanding Pivot                                           |
//+------------------------------------------------------------------+
void DetectExpandingPivot(int idx)
{
   if(!expPivotReady && pivReady && pivLowReady)
   {
      if(pivLowVal[0] < pivLowVal[1] && pivHighVal[1] > pivHighVal[0])
      {
         expPivotReady = true;
         e0 = pivLowTime[0];
         ep0 = pivLowVal[0];
         e1 = pivHighTime[1];
         ep1 = pivHighVal[1];
         e2 = pivLowTime[1];
         ep2 = pivLowVal[1];
      }
   }
}

//+------------------------------------------------------------------+
//| Build Fibonacci Square Field                                     |
//+------------------------------------------------------------------+
void BuildFibSquareField()
{
   if(!foundD2 || !foundS2) return;
   ObjectDelete(0, "EA_FibField");
   ObjectCreate(0, "EA_FibField", OBJ_RECTANGLE, 0, demand2.t, demand2.price, supply2.t, supply2.price);
   ObjectSetInteger(0, "EA_FibField", OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, "EA_FibField", OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Build Silhouette                                                 |
//+------------------------------------------------------------------+
void BuildSilhouette()
{
   if(pivReady && pivLowReady)
   {
      svT1 = pivHighTime[1];
      svP1 = pivHighVal[1];
      svT2 = pivLowTime[1];
      svP2 = pivLowVal[1];
      svReady = true;
   }
}

//+------------------------------------------------------------------+
//| Build Outward Frequency                                          |
//+------------------------------------------------------------------+
void BuildOutwardFrequency()
{
   if(!ofReady && pivReady)
   {
      ofT1 = pivHighTime[0];
      ofP1 = pivHighVal[0];
      ofT2 = TimeCurrent();
      ofP2 = pivHighVal[0];
      ofReady = true;
   }
}

//+------------------------------------------------------------------+
//| Calculate Pitchfork                                              |
//+------------------------------------------------------------------+
void CalculatePitchfork()
{
   int highIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, MemoryWindowBars, 1);
   int lowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, MemoryWindowBars, 1);
   double high = iHigh(_Symbol, PERIOD_CURRENT, highIdx);
   double low = iLow(_Symbol, PERIOD_CURRENT, lowIdx);
   pitchforkMedian = (high + low) / 2;
   pitchforkUpper = high;
   pitchforkLower = low;
}

//+------------------------------------------------------------------+
//| Calculate Schiff Pitchfork                                       |
//+------------------------------------------------------------------+
void CalculateSchiffPitchfork()
{
   if(!pivReady || !pivLowReady) return;
   double pivotA = pivHighVal[0];
   double pivotB = pivLowVal[0];
   double pivotC = pivHighVal[1];
   double midPointAB = (pivotA + pivotB) / 2;
   schiffMedian = midPointAB + (pivotC - midPointAB) / 2;
   schiffUpper = pivotA;
   schiffLower = pivotB;
   DrawSchiffPitchfork();
}

//+------------------------------------------------------------------+
//| Draw Schiff Pitchfork                                            |
//+------------------------------------------------------------------+
void DrawSchiffPitchfork()
{
   if(schiffMedian == 0) return;
   string medianName = "EA_SchiffPitchforkMedian";
   if(ObjectFind(0, medianName) < 0) ObjectCreate(0, medianName, OBJ_HLINE, 0, 0, schiffMedian);
   ObjectSetDouble(0, medianName, OBJPROP_PRICE, schiffMedian);
   ObjectSetInteger(0, medianName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, medianName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, medianName, OBJPROP_STYLE, STYLE_DOT);

   string medianText = "EA_SchiffPitchforkMedianText";
   if(ObjectFind(0, medianText) < 0) ObjectCreate(0, medianText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), schiffMedian + 5 * Point());
   ObjectSetString(0, medianText, OBJPROP_TEXT, "Schiff Pitchfork Median");
   ObjectSetInteger(0, medianText, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, medianText, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, medianText, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Build Omni Fibonacci Square Field                                |
//+------------------------------------------------------------------+
double BuildOmniFibSquareField()
{
   int highIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, MemoryWindowBars, 1);
   int lowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, MemoryWindowBars, 1);
   double high = iHigh(_Symbol, PERIOD_CURRENT, highIdx);
   double low = iLow(_Symbol, PERIOD_CURRENT, lowIdx);
   double range = high - low;
   return low + range * FibExtTarget_FF;
}

//+------------------------------------------------------------------+
//| Calculate Newtonian Projection                                   |
//+------------------------------------------------------------------+
double CalculateNewtonianProjection()
{
   int lowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, NewtonBars, 1);
   double low = iLow(_Symbol, PERIOD_CURRENT, lowIdx);
   double velocity = (iClose(_Symbol, PERIOD_CURRENT, 1) - iClose(_Symbol, PERIOD_CURRENT, NewtonBars)) / NewtonBars;
   return low + velocity * NewtonBars;
}

//+------------------------------------------------------------------+
//| Is Pressure Bar                                                  |
//+------------------------------------------------------------------+
bool IsPressureBar(int shift)
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double low = iLow(_Symbol, PERIOD_CURRENT, shift);
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   double body = MathAbs(close - open);
   double wick = MathMax(high - close, open - low);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) != 1) return false;
   return wick > body * 2 && (high - low) > atr[0];
}

//+------------------------------------------------------------------+
//| Detect Failure Swing                                             |
//+------------------------------------------------------------------+
bool DetectFailureSwing(int shift, int dir)
{
   bool fractal = (dir == 0 ? IsFractalLow(shift, FractalMinor_FF) : IsFractalHigh(shift, FractalMinor_FF));
   bool candle = (dir == 0 ? iClose(_Symbol, PERIOD_CURRENT, shift) > iOpen(_Symbol, PERIOD_CURRENT, shift) : iClose(_Symbol, PERIOD_CURRENT, shift) < iOpen(_Symbol, PERIOD_CURRENT, shift));
   bool nearZone = (dir == 0 ? iLow(_Symbol, PERIOD_CURRENT, shift) <= DemandZone.price : iHigh(_Symbol, PERIOD_CURRENT, shift) >= SupplyZone.price);
   return (fractal && candle && nearZone);
}

//+------------------------------------------------------------------+
//| Detect Flow                                                      |
//+------------------------------------------------------------------+
bool DetectFlow(int shift)
{
   int lowCount = 0;
   for(int i = shift; i < shift + StandingBarsMin_FF && i < iBars(_Symbol, PERIOD_CURRENT); i++)
   {
      double atr[1];
      if(CopyBuffer(atrHandle, 0, i, 1, atr) == 1)
      {
         if((iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i)) < atr[0] * 0.5) lowCount++;
      }
   }
   return (lowCount < StandingBarsMin_FF / 2);
}

//+------------------------------------------------------------------+
//| Get Fibonacci Quality                                            |
//+------------------------------------------------------------------+
int GetFibQuality()
{
   return fibQuality;
}

//+------------------------------------------------------------------+
//| Detect Flow 2                                                    |
//+------------------------------------------------------------------+
void DetectFlow2(int idx)
{
   double range = iHigh(_Symbol, PERIOD_CURRENT, idx) - iLow(_Symbol, PERIOD_CURRENT, idx);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, idx, 1, atr) == 1)
   {
      if(range < atr[0] && (iHigh(_Symbol, PERIOD_CURRENT, idx + 1) - iLow(_Symbol, PERIOD_CURRENT, idx + 1)) < atr[0])
      {
         standingCount++;
         if(standingCount >= StandingBarsMin_FF) isStanding = true;
      }
      else
      {
         standingCount = 0;
         isStanding = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Failure Swing 2                                           |
//+------------------------------------------------------------------+
bool DetectFailureSwing2(int idx)
{
   return (iHigh(_Symbol, PERIOD_CURRENT, idx + 1) >= supply2.price && iClose(_Symbol, PERIOD_CURRENT, idx) < supply2.price);
}

//+------------------------------------------------------------------+
//| Detect Hook Pattern                                              |
//+------------------------------------------------------------------+
bool DetectHook(int shift, int direction)
{
   double atr[1], adx[2];
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) != 1) return false;
   if(CopyBuffer(adxHandle, 0, shift, 2, adx) != 2) return false;
   if(adx[0] < 25) return false; // Trend filter with ADX
   
   double fibLevel = (direction == 1) ? 
      (SupplyZone.price - (SupplyZone.price - DemandZone.price) * 0.618) :
      (DemandZone.price + (SupplyZone.price - DemandZone.price) * 0.618);

   bool impulse = false;
   for(int i = shift; i < shift + 3 && i < iBars(_Symbol, PERIOD_CURRENT); i++)
   {
      double range = iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i);
      if(range >= 2 * atr[0] && 
         ((direction == 1 && iClose(_Symbol, PERIOD_CURRENT, i) > iOpen(_Symbol, PERIOD_CURRENT, i)) ||
          (direction == -1 && iClose(_Symbol, PERIOD_CURRENT, i) < iOpen(_Symbol, PERIOD_CURRENT, i))))
      {
         impulse = true;
         break;
      }
   }
   if(!impulse) return false;

   int pullbackCount = 0;
   for(int i = shift; i < shift + 3 && i < iBars(_Symbol, PERIOD_CURRENT); i++)
   {
      double range = iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i);
      if(range < 0.5 * atr[0]) pullbackCount++;
      if(pullbackCount >= 2) break;
   }
   return (pullbackCount >= 2);
}

//+------------------------------------------------------------------+
//| Draw Hook Pattern on Chart                                       |
//+------------------------------------------------------------------+
void DrawHook(int shift)
{
   if(DetectHook(shift, 1))
   {
      string buyHookArrow = "EA_BuyHookArrow_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift));
      ObjectCreate(0, buyHookArrow, OBJ_ARROW_UP, 0, iTime(_Symbol, PERIOD_CURRENT, shift), iLow(_Symbol, PERIOD_CURRENT, shift) - 5 * Point());
      ObjectSetInteger(0, buyHookArrow, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buyHookArrow, OBJPROP_WIDTH, 2);

      string buyHookText = "EA_BuyHookText_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift));
      ObjectCreate(0, buyHookText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, shift), iLow(_Symbol, PERIOD_CURRENT, shift) - 10 * Point());
      ObjectSetString(0, buyHookText, OBJPROP_TEXT, "Hook Buy at " + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift)));
      ObjectSetInteger(0, buyHookText, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buyHookText, OBJPROP_FONTSIZE, 8);
   }
   if(DetectHook(shift, -1))
   {
      string sellHookArrow = "EA_SellHookArrow_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift));
      ObjectCreate(0, sellHookArrow, OBJ_ARROW_DOWN, 0, iTime(_Symbol, PERIOD_CURRENT, shift), iHigh(_Symbol, PERIOD_CURRENT, shift) + 5 * Point());
      ObjectSetInteger(0, sellHookArrow, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sellHookArrow, OBJPROP_WIDTH, 2);

      string sellHookText = "EA_SellHookText_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift));
      ObjectCreate(0, sellHookText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, shift), iHigh(_Symbol, PERIOD_CURRENT, shift) + 10 * Point());
      ObjectSetString(0, sellHookText, OBJPROP_TEXT, "Hook Sell at " + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift)));
      ObjectSetInteger(0, sellHookText, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sellHookText, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
//| Detect Frequency Breakout                                        |
//+------------------------------------------------------------------+
bool DetectFrequencyBreakout(double price)
{
   for(int i = 0; i < allFreqLineCount; i++)
   {
      if(!allFreqLines[i].isActive) continue;
      double v = allFreqLines[i].p1 + (allFreqLines[i].p2 - allFreqLines[i].p1) *
                 ((double)(iTime(_Symbol, PERIOD_CURRENT, 0) - allFreqLines[i].t1)) /
                 (allFreqLines[i].t2 - allFreqLines[i].t1);
      if((price > v && iClose(_Symbol, PERIOD_CURRENT, 1) <= v) ||
         (price < v && iClose(_Symbol, PERIOD_CURRENT, 1) >= v))
      {
         DrawBreakoutMarker(iTime(_Symbol, PERIOD_CURRENT, 0), v);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Draw Breakout Marker                                             |
//+------------------------------------------------------------------+
void DrawBreakoutMarker(datetime time, double price)
{
   string markerName = "EA_Breakout_" + TimeToString(time);
   ObjectCreate(0, markerName, OBJ_TEXT, 0, time, price + 5 * Point());
   ObjectSetString(0, markerName, OBJPROP_TEXT, "Breakout");
   ObjectSetInteger(0, markerName, OBJPROP_COLOR, clrBlue);
}

//+------------------------------------------------------------------+
//| Draw Hybrid Bar Marker                                           |
//+------------------------------------------------------------------+
void DrawHybridBarMarker(int shift)
{
   string markerName = "EA_HybridMarker_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, shift));
   double price = (iHigh(_Symbol, PERIOD_CURRENT, shift) + iLow(_Symbol, PERIOD_CURRENT, shift)) / 2;
   ObjectCreate(0, markerName, OBJ_ELLIPSE, 0, iTime(_Symbol, PERIOD_CURRENT, shift), price);
   ObjectSetInteger(0, markerName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 2);
   ObjectSetDouble(0, markerName, OBJPROP_SCALE, 0.02);
}

//+------------------------------------------------------------------+
//| Detect latest supply/demand zones                                |
//+------------------------------------------------------------------+
void ScanZones()
{
   int highestIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, MemoryWindowBars, 1);
   SupplyZone.price = iHigh(_Symbol, PERIOD_CURRENT, highestIdx) + ZoneOffsetPips_FF * Point();
   SupplyZone.t = iTime(_Symbol, PERIOD_CURRENT, highestIdx);
   SupplyZone.flipped = false;
   SupplyZone.lastTouched = highestIdx;
   SupplyZone.isActive = true;
   SupplyZone.touches = 0;
   tookSell = false;

   int lowestIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, MemoryWindowBars, 1);
   DemandZone.price = iLow(_Symbol, PERIOD_CURRENT, lowestIdx) - ZoneOffsetPips_FF * Point();
   DemandZone.t = iTime(_Symbol, PERIOD_CURRENT, lowestIdx);
   DemandZone.flipped = false;
   DemandZone.lastTouched = lowestIdx;
   DemandZone.isActive = true;
   DemandZone.touches = 0;
   tookBuy = false;
}

//+------------------------------------------------------------------+
//| Scan secondary zones (Omni)                                      |
//+------------------------------------------------------------------+
void ScanZones2()
{
   foundD2 = false;
   foundS2 = false;
   int highestIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, ZoneLen_Omni, 1);
   supply2.t = iTime(_Symbol, PERIOD_CURRENT, highestIdx);
   supply2.price = iHigh(_Symbol, PERIOD_CURRENT, highestIdx);
   supply2.lastTouched = highestIdx;
   supply2.isActive = true;
   supply2.touches = 0;
   foundS2 = true;

   int lowestIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, ZoneLen_Omni, 1);
   demand2.t = iTime(_Symbol, PERIOD_CURRENT, lowestIdx);
   demand2.price = iLow(_Symbol, PERIOD_CURRENT, lowestIdx);
   demand2.lastTouched = lowestIdx;
   demand2.isActive = true;
   demand2.touches = 0;
   foundD2 = true;
}

//+------------------------------------------------------------------+
//| Draw supply/demand zones                                         |
//+------------------------------------------------------------------+
void DrawZones()
{
   if(SupplyZone.t != 0)
   {
      string supplyName = "EA_SUPPLY";
      if(ObjectFind(0, supplyName) < 0) ObjectCreate(0, supplyName, OBJ_HLINE, 0, 0, SupplyZone.price);
      ObjectSetDouble(0, supplyName, OBJPROP_PRICE, SupplyZone.price);
      ObjectSetInteger(0, supplyName, OBJPROP_COLOR, SupplyZone.flipped ? clrGreen : clrRed);
      ObjectSetInteger(0, supplyName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, supplyName, OBJPROP_STYLE, STYLE_SOLID);

      string supplyText = "EA_SupplyText";
      if(ObjectFind(0, supplyText) < 0) ObjectCreate(0, supplyText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), SupplyZone.price + 5 * Point());
      ObjectSetString(0, supplyText, OBJPROP_TEXT, SupplyZone.flipped ? "Supply Zone - Flipped" : "Supply Zone");
      ObjectSetInteger(0, supplyText, OBJPROP_COLOR, SupplyZone.flipped ? clrGreen : clrRed);
      ObjectSetInteger(0, supplyText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, supplyText, OBJPROP_FONT, "Arial");
   }

   if(DemandZone.t != 0)
   {
      string demandName = "EA_DEMAND";
      if(ObjectFind(0, demandName) < 0) ObjectCreate(0, demandName, OBJ_HLINE, 0, 0, DemandZone.price);
      ObjectSetDouble(0, demandName, OBJPROP_PRICE, DemandZone.price);
      ObjectSetInteger(0, demandName, OBJPROP_COLOR, DemandZone.flipped ? clrRed : clrGreen);
      ObjectSetInteger(0, demandName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, demandName, OBJPROP_STYLE, STYLE_SOLID);

      string demandText = "EA_DemandText";
      if(ObjectFind(0, demandText) < 0) ObjectCreate(0, demandText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), DemandZone.price - 5 * Point());
      ObjectSetString(0, demandText, OBJPROP_TEXT, DemandZone.flipped ? "Demand Zone - Flipped" : "Demand Zone");
      ObjectSetInteger(0, demandText, OBJPROP_COLOR, DemandZone.flipped ? clrRed : clrGreen);
      ObjectSetInteger(0, demandText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, demandText, OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Draw secondary zones (Omni)                                      |
//+------------------------------------------------------------------+
void DrawZones2()
{
   if(foundD2)
   {
      color dcol = demand2.flipped ? clrRed : clrLime;
      string omniDemandName = "EA_OmniDemand";
      if(ObjectFind(0, omniDemandName) < 0) ObjectCreate(0, omniDemandName, OBJ_HLINE, 0, 0, demand2.price);
      ObjectSetDouble(0, omniDemandName, OBJPROP_PRICE, demand2.price);
      ObjectSetInteger(0, omniDemandName, OBJPROP_COLOR, dcol);
      ObjectSetInteger(0, omniDemandName, OBJPROP_WIDTH, 2);

      string omniDemandText = "EA_OmniDemandText";
      if(ObjectFind(0, omniDemandText) < 0) ObjectCreate(0, omniDemandText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), demand2.price - 5 * Point());
      ObjectSetString(0, omniDemandText, OBJPROP_TEXT, demand2.flipped ? "Omni Demand - Flipped" : "Omni Demand");
      ObjectSetInteger(0, omniDemandText, OBJPROP_COLOR, dcol);
      ObjectSetInteger(0, omniDemandText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, omniDemandText, OBJPROP_FONT, "Arial");
   }

   if(foundS2)
   {
      color scol = supply2.flipped ? clrLime : clrRed;
      string omniSupplyName = "EA_OmniSupply";
      if(ObjectFind(0, omniSupplyName) < 0) ObjectCreate(0, omniSupplyName, OBJ_HLINE, 0, 0, supply2.price);
      ObjectSetDouble(0, omniSupplyName, OBJPROP_PRICE, supply2.price);
      ObjectSetInteger(0, omniSupplyName, OBJPROP_COLOR, scol);
      ObjectSetInteger(0, omniSupplyName, OBJPROP_WIDTH, 2);

      string omniSupplyText = "EA_OmniSupplyText";
      if(ObjectFind(0, omniSupplyText) < 0) ObjectCreate(0, omniSupplyText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), supply2.price + 5 * Point());
      ObjectSetString(0, omniSupplyText, OBJPROP_TEXT, supply2.flipped ? "Omni Supply - Flipped" : "Omni Supply");
      ObjectSetInteger(0, omniSupplyText, OBJPROP_COLOR, scol);
      ObjectSetInteger(0, omniSupplyText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, omniSupplyText, OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Entry Condition Buy                                              |
//+------------------------------------------------------------------+
bool IsBuySetup(double ask)
{
   double range = SupplyZone.price - DemandZone.price;
   double fibEntry = SupplyZone.price - range * FibRetraceLevel_FF;

   if(ask >= DemandZone.price && ask <= SupplyZone.price && ask <= fibEntry)
   {
      fibTouchCount++;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Entry Condition Sell                                             |
//+------------------------------------------------------------------+
bool IsSellSetup(double bid)
{
   double range = SupplyZone.price - DemandZone.price;
   double fibEntry = DemandZone.price + range * FibRetraceLevel_FF;

   if(bid >= DemandZone.price && bid <= SupplyZone.price && bid >= fibEntry)
   {
      fibTouchCount++;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Automated Trading Logic                                          |
//+------------------------------------------------------------------+
void AutomatedTradingLogic(double price, bool hybrid, bool fsBuy, bool fsSell, bool flow, int fq, double buyScore, double sellScore, int flowType)
{
   if(RestrictTradingHours && !IsTradingTimeAllowed()) return;

   double buyLevel = DemandZone.price + (SupplyZone.price - DemandZone.price) * FibRetraceLevel_FF;
   double sellLevel = SupplyZone.price - (SupplyZone.price - DemandZone.price) * FibRetraceLevel_FF;
   bool buyZone = price >= DemandZone.price && price <= SupplyZone.price;
   bool sellZone = price >= DemandZone.price && price <= SupplyZone.price;

   double stopLossPips = atrCurrent / Point() * 2.0;
   double takeProfitPips = stopLossPips * RiskRewardRatio;

   bool hookBuy = EnableHookDetection ? DetectHook(1, 1) : false;
   bool hookSell = EnableHookDetection ? DetectHook(1, -1) : false;

   double baseLot = CalculateDynamicLotSize(stopLossPips);
   double finalLot = (hookBuy || hookSell) ? baseLot * HookLotMultiplier : baseLot;

   if(hookBuy && buyScore < RequiredHookScore) return;
   if(!hookBuy && buyScore < MinScoreThreshold) return;
   if(hookSell && sellScore < RequiredHookScore) return;
   if(!hookSell && sellScore < MinScoreThreshold) return;

   if(hookBuy || hookSell) takeProfitPips = stopLossPips * RiskRewardRatio * HookTPMultiplier;

   pitchforkBuyCondition = UseSchiffPitchfork ? (price > schiffMedian && price < schiffUpper) : (price > pitchforkMedian && price < pitchforkUpper);
   pitchforkSellCondition = UseSchiffPitchfork ? (price < schiffMedian && price > schiffLower) : (price < pitchforkMedian && price > pitchforkLower);

   if(signal == 1 && buyZone && flow && (hybrid || fsBuy || hookBuy) && fq >= MEDIUM && 
      ((hookBuy && buyScore >= RequiredHookScore) || (!hookBuy && buyScore >= MinScoreThreshold)) && 
      !tookBuy && price <= buyLevel && pitchforkBuyCondition && flowType == 2 && IsBuySetup(price))
   {
      double sl = price - stopLossPips * Point();
      double tp = price + takeProfitPips * Point();
      trade.Buy(finalLot, _Symbol, price, sl, tp, hookBuy ? "AutoBuy_Hook_v6" : "AutoBuy_v6");
      if(statCount < 500) LogTradeResult(hookBuy ? "Hook" : "Standard", price, sl, tp, false);
      if(signalStatCount < 100) LogSignalStat(hookBuy ? "Hook" : "Standard", false, (tp - price) / (price - sl), iTime(_Symbol, PERIOD_CURRENT, 0), price, 0, 0);
      tookBuy = true;
   }

   if(signal == -1 && sellZone && flow && (hybrid || fsSell || hookSell) && fq >= MEDIUM && 
      ((hookSell && sellScore >= RequiredHookScore) || (!hookSell && sellScore >= MinScoreThreshold)) && 
      !tookSell && price >= sellLevel && pitchforkSellCondition && flowType == 2 && IsSellSetup(price))
   {
      double sl = price + stopLossPips * Point();
      double tp = price - takeProfitPips * Point();
      trade.Sell(finalLot, _Symbol, price, sl, tp, hookSell ? "AutoSell_Hook_v6" : "AutoSell_v6");
      if(statCount < 500) LogTradeResult(hookSell ? "Hook" : "Standard", price, sl, tp, false);
      if(signalStatCount < 100) LogSignalStat(hookSell ? "Hook" : "Standard", false, (price - tp) / (sl - price), iTime(_Symbol, PERIOD_CURRENT, 0), price, 0, 0);
      tookSell = true;
   }
}

//+------------------------------------------------------------------+
//| Place Order                                                      |
//+------------------------------------------------------------------+
void PlaceOrder(int type, double entry, double sl, double tp, string comment)
{
   long minDistPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = minDistPoints * Point();
   double lotSize = CalculateDynamicLotSize((type == ORDER_TYPE_BUY ? (entry - sl) : (sl - entry)) / Point());
   if(type == ORDER_TYPE_BUY)
   {
      sl = MathMax(sl, entry - minDist);
      tp = MathMax(tp, entry + minDist);
      trade.Buy(lotSize, _Symbol, entry, sl, tp, comment);
   }
   else
   {
      sl = MathMin(sl, entry + minDist);
      tp = MathMin(tp, entry - minDist);
      trade.Sell(lotSize, _Symbol, entry, sl, tp, comment);
   }
   if(statCount < 500) LogTradeResult(comment, entry, sl, tp, false);
}

//+------------------------------------------------------------------+
//| Place Order for Triple Confluence                                |
//+------------------------------------------------------------------+
void PlaceOrder2(int type, string cm)
{
   if(!manipulationDetected) return;
   double sl = (type == ORDER_TYPE_SELL ? manipLevel + ManipStopOffsetPips_FF * Point() : manipLevel - ManipStopOffsetPips_FF * Point());
   double tp = (type == ORDER_TYPE_SELL ? manipLevel - (manipLevel - demand2.price) * FibManipExtTarget_Omni : 
                manipLevel + (supply2.price - manipLevel) * FibManipExtTarget_Omni);
   SendOrder(type, sl, tp, cm);
}

//+------------------------------------------------------------------+
//| Check if Order Exists                                            |
//+------------------------------------------------------------------+
bool OrderExists(int type, string cmt)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetInteger(POSITION_TYPE) == type && 
            PositionGetString(POSITION_COMMENT) == cmt)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Send Order for Triple Confluence                                 |
//+------------------------------------------------------------------+
void SendOrder(int type, double sl, double tp, string cmt)
{
   if(OrderExists(type, cmt)) return;
   double entry = (type == ORDER_TYPE_SELL ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double lotSize = CalculateDynamicLotSize((type == ORDER_TYPE_SELL ? (sl - entry) : (entry - sl)) / Point());
   if(type == ORDER_TYPE_BUY)
   {
      trade.Buy(lotSize, _Symbol, entry, sl, tp, cmt);
   }
   else
   {
      trade.Sell(lotSize, _Symbol, entry, sl, tp, cmt);
   }
   if(statCount < 500) LogTradeResult(cmt, entry, sl, tp, false);
}

//+------------------------------------------------------------------+
//| Manage Open Orders                                               |
//+------------------------------------------------------------------+
void ManageOpenOrders()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            (PositionGetInteger(POSITION_MAGIC) == MagicNumber || PositionGetInteger(POSITION_MAGIC) == MagicNumber + 1))
         {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
            double profitPoints = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? (currentPrice - entryPrice) : (entryPrice - currentPrice)) / Point();

            if(profitPoints >= BreakEvenPoints && PositionGetDouble(POSITION_SL) != entryPrice)
            {
               trade.PositionModify(PositionGetTicket(i), entryPrice, PositionGetDouble(POSITION_TP));
            }
            if(profitPoints >= TrailingStartPoints && UseTrailingStop)
            {
               UpdateTrailingStops(PositionGetTicket(i));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Trailing Stops                                            |
//+------------------------------------------------------------------+
void UpdateTrailingStops(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;

   double trailingStop = (StringFind(PositionGetString(POSITION_COMMENT), "Hook") >= 0) ? 
                         HookTrailingStopPips * Point() : TrailingStopPips * Point();
   double newSL;
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailingStop, Digits());
      if(newSL > PositionGetDouble(POSITION_SL)) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailingStop, Digits());
      if(newSL < PositionGetDouble(POSITION_SL)) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
   }
}

//+------------------------------------------------------------------+
//| Detect Fractal High                                              |
//+------------------------------------------------------------------+
bool IsFractalHigh(int index, int depth)
{
   if(index < depth / 2 || index + depth / 2 >= iBars(_Symbol, PERIOD_CURRENT)) return false;
   for(int i = 1; i <= depth / 2; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, index) <= iHigh(_Symbol, PERIOD_CURRENT, index - i) || iHigh(_Symbol, PERIOD_CURRENT, index) <= iHigh(_Symbol, PERIOD_CURRENT, index + i)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Detect Fractal Low                                               |
//+------------------------------------------------------------------+
bool IsFractalLow(int index, int depth)
{
   if(index < depth / 2 || index + depth / 2 >= iBars(_Symbol, PERIOD_CURRENT)) return false;
   for(int i = 1; i <= depth / 2; i++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, index) >= iLow(_Symbol, PERIOD_CURRENT, index - i) || iLow(_Symbol, PERIOD_CURRENT, index) >= iLow(_Symbol, PERIOD_CURRENT, index + i)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Detect Fractal High (Omni Version)                               |
//+------------------------------------------------------------------+
bool IsFractalHigh2(int i, int p)
{
   int m = i + (p - 1) / 2;
   if(m < (p - 1) / 2 || m + (p - 1) / 2 >= iBars(_Symbol, PERIOD_CURRENT)) return false;
   for(int k = m - (p - 1) / 2; k <= m + (p - 1) / 2; k++)
   {
      if(k != m && iHigh(_Symbol, PERIOD_CURRENT, k) >= iHigh(_Symbol, PERIOD_CURRENT, m)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Detect Fractal Low (Omni Version)                                |
//+------------------------------------------------------------------+
bool IsFractalLow2(int i, int p)
{
   int m = i + (p - 1) / 2;
   if(m < (p - 1) / 2 || m + (p - 1) / 2 >= iBars(_Symbol, PERIOD_CURRENT)) return false;
   for(int k = m - (p - 1) / 2; k <= m + (p - 1) / 2; k++)
   {
      if(k != m && iLow(_Symbol, PERIOD_CURRENT, k) <= iLow(_Symbol, PERIOD_CURRENT, m)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size                                       |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double stopLossPips)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotSize = riskAmount / (stopLossPips * Point() * tickValue);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return NormalizeDouble(MathMax(minLot, MathMin(maxLot, lotSize)), LotStepDigits());
}

//+------------------------------------------------------------------+
//| Lot Step Digits                                                  |
//+------------------------------------------------------------------+
int LotStepDigits()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step == 0.1) return 1;
   if(step == 0.01) return 2;
   return 0;
}

//+------------------------------------------------------------------+
//| Check Trading Time Restrictions                                  |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   int hour = timeStruct.hour;
   return (hour >= StartTradingHour && hour < EndTradingHour);
}

//+------------------------------------------------------------------+
//| Detect Von Restorff Effect                                       |
//+------------------------------------------------------------------+
bool DetectVonRestorffEffect(int shift)
{
   double smaVolume[1];
   long volume[1];  // آرایه از نوع long
   if(CopyBuffer(smaVolumeHandle, 0, shift, 1, smaVolume) != 1) return false;
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, shift, 1, volume) != 1) return false;
   return ((double)volume[0] > smaVolume[0] * 2.0);  // تبدیل به double برای مقایسه
}
//+------------------------------------------------------------------+
//| Detect Bandwagon Effect                                          |
//+------------------------------------------------------------------+
bool DetectBandwagonEffect(int shift)
{
   long volume[5];
   for(int i = 0; i < 5; i++)
      volume[i] = iVolume(_Symbol, PERIOD_CURRENT, shift + i);
   double avgVolume = 0;
   for(int i = 1; i < 5; i++) avgVolume += (double)volume[i];
   avgVolume /= 4;
   return (volume[0] > avgVolume * 2.0 && iClose(_Symbol, PERIOD_CURRENT, shift) > iOpen(_Symbol, PERIOD_CURRENT, shift));
}

//+------------------------------------------------------------------+
//| Analyze Market Flow (ADX and Bollinger Bands)                    |
//+------------------------------------------------------------------+
void AnalyzeMarketFlow()
{
   double adxBuffer[1];
   if(CopyBuffer(adxHandle, 0, 1, 1, adxBuffer) == 1)
   {
      adxValue = adxBuffer[0];
   }
   double bbMiddleBuffer[1], bbUpperBuffer[1], bbLowerBuffer[1];
   if(CopyBuffer(bbHandle, 0, 1, 1, bbMiddleBuffer) == 1 && 
      CopyBuffer(bbHandle, 1, 1, 1, bbUpperBuffer) == 1 && 
      CopyBuffer(bbHandle, 2, 1, 1, bbLowerBuffer) == 1)
   {
      bbMiddle = bbMiddleBuffer[0];
      bbUpper = bbUpperBuffer[0];
      bbLower = bbLowerBuffer[0];
   }
}

//+------------------------------------------------------------------+
//| Calculate Multiple Pitchforks                                    |
//+------------------------------------------------------------------+
void CalculateMultiplePitchforks()
{
   int highIdx1 = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, MemoryWindowBars, 1);
   int lowIdx1 = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, MemoryWindowBars, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, highIdx1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, lowIdx1);
   double median1 = (high1 + low1) / 2;

   int highIdx2 = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, MemoryWindowBars / 2, 1);
   int lowIdx2 = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, MemoryWindowBars / 2, 1);
   double high2 = iHigh(_Symbol, PERIOD_CURRENT, highIdx2);
   double low2 = iLow(_Symbol, PERIOD_CURRENT, lowIdx2);
   double median2 = (high2 + low2) / 2;

   pitchforkMedian = (median1 + median2) / 2;
   pitchforkUpper = MathMax(high1, high2);
   pitchforkLower = MathMin(low1, low2);
}

//+------------------------------------------------------------------+
//| Draw Signal Arrows                                               |
//+------------------------------------------------------------------+
void DrawSignalArrows(bool hybrid, bool fsBuy, bool fsSell)
{
   if(fsBuy && signal == 1 && (vonRestorffDetected || bandwagonDetected))
   {
      string buyArrow = "EA_BuyArrow_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, 0));
      ObjectCreate(0, buyArrow, OBJ_ARROW_UP, 0, iTime(_Symbol, PERIOD_CURRENT, 0), iLow(_Symbol, PERIOD_CURRENT, 0) - 5 * Point());
      ObjectSetInteger(0, buyArrow, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buyArrow, OBJPROP_WIDTH, 2);
   }
   if(fsSell && signal == -1 && (vonRestorffDetected || bandwagonDetected))
   {
      string sellArrow = "EA_SellArrow_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, 0));
      ObjectCreate(0, sellArrow, OBJ_ARROW_DOWN, 0, iTime(_Symbol, PERIOD_CURRENT, 0), iHigh(_Symbol, PERIOD_CURRENT, 0) + 5 * Point());
      ObjectSetInteger(0, sellArrow, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sellArrow, OBJPROP_WIDTH, 2);
   }
}

//+------------------------------------------------------------------+
//| Display Candle Time Remaining                                    |
//+------------------------------------------------------------------+
void DisplayCandleTimeRemaining()
{
   string name = "EA_CandleTimeRemaining";
   if(iBars(_Symbol, PERIOD_CURRENT) < 1) return;

   int timeframeSeconds = PeriodSeconds();
   datetime currentTime = TimeCurrent();
   datetime nextCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0) + timeframeSeconds;
   int secondsRemaining = (int)(nextCandleTime - currentTime);

   if(secondsRemaining < 0) secondsRemaining = 0;

   int minutes = secondsRemaining / 60;
   int seconds = secondsRemaining % 60;
   string timeText = StringFormat("Time Remaining: %02d:%02d", minutes, seconds);

   double pricePosition = iHigh(_Symbol, PERIOD_CURRENT, 0) + CandleTimeOffset * Point();

   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, timeText);
      ObjectSetDouble(0, name, OBJPROP_PRICE, pricePosition);
      ObjectSetInteger(0, name, OBJPROP_TIME, iTime(_Symbol, PERIOD_CURRENT, 0));
   }
   else
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), pricePosition);
      ObjectSetString(0, name, OBJPROP_TEXT, timeText);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
//| Add Multi Frequency Line                                         |
//+------------------------------------------------------------------+
void AddMultiFreqLine(datetime t1, double p1, datetime t2, double p2, string freqType)
{
   if(allFreqLineCount >= 20) return;
   for(int i = 0; i < allFreqLineCount; i++)
   {
      if(allFreqLines[i].t1 == t1 && allFreqLines[i].p1 == p1 && allFreqLines[i].t2 == t2 && allFreqLines[i].p2 == p2 && allFreqLines[i].freqType == freqType)
      {
         allFreqLines[i].isActive = true;
         return;
      }
   }
   MultiFreqLine newLine;
   newLine.t1 = t1;
   newLine.t2 = t2;
   newLine.p1 = p1;
   newLine.p2 = p2;
   newLine.touches = 0;
   newLine.isActive = true;
   newLine.freqType = freqType;
   allFreqLines[allFreqLineCount++] = newLine;
}

//+------------------------------------------------------------------+
//| Validate Frequency Lines                                         |
//+------------------------------------------------------------------+
void ValidateFreqLines(double price)
{
   for(int i = 0; i < allFreqLineCount; i++)
   {
      double v = (allFreqLines[i].p2 - allFreqLines[i].p1) / ((double)(allFreqLines[i].t2 - allFreqLines[i].t1)) * ((double)(iTime(_Symbol, PERIOD_CURRENT, 0) - allFreqLines[i].t1)) + allFreqLines[i].p1;
      if(MathAbs(price - v) < ZoneOffsetPips_FF * Point()) allFreqLines[i].touches++;
      allFreqLines[i].isActive = (allFreqLines[i].touches >= MinFreqTouch);
   }
}

//+------------------------------------------------------------------+
//| Detect Flow Type                                                 |
//+------------------------------------------------------------------+
int DetectFlowType()
{
   int updown = 0, noise = 0, n = SmoothFlowBars;
   for(int i = 1; i <= n && i < iBars(_Symbol, PERIOD_CURRENT) - 1; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, i) > iHigh(_Symbol, PERIOD_CURRENT, i + 1) && iLow(_Symbol, PERIOD_CURRENT, i) > iLow(_Symbol, PERIOD_CURRENT, i + 1)) updown++;
      else if(iHigh(_Symbol, PERIOD_CURRENT, i) < iHigh(_Symbol, PERIOD_CURRENT, i + 1) && iLow(_Symbol, PERIOD_CURRENT, i) > iLow(_Symbol, PERIOD_CURRENT, i + 1)) noise++;
   }
   double ratio = (double)updown / n;
   if(ratio > 0.7) return 2;
   if(ratio > 0.4) return 1;
   return 0;
}

//+------------------------------------------------------------------+
//| Update Pivots                                                    |
//+------------------------------------------------------------------+
void UpdatePivots()
{
   pCountH = 0; pCountL = 0;
   for(int i = FractalMajor_FF; i < iBars(_Symbol, PERIOD_CURRENT) - FractalMajor_FF && pCountH < 10; i++)
      if(IsFractalHigh(i, FractalMajor_FF)) pivotHighs[pCountH++] = i;
   for(int i = FractalMajor_FF; i < iBars(_Symbol, PERIOD_CURRENT) - FractalMajor_FF && pCountL < 10; i++)
      if(IsFractalLow(i, FractalMajor_FF)) pivotLows[pCountL++] = i;
}

//+------------------------------------------------------------------+
//| Compute Signal Score                                             |
//+------------------------------------------------------------------+
double ComputeSignalScore(bool dfb, bool hybrid, bool freq, int touches, int flowType, bool volumeConfirm)
{
   double score = 0;
   if(dfb) score += 2;
   if(hybrid) score += 1;
   if(freq) score += 1;
   if(touches >= 4) score += 1;
   if(flowType == 2) score += 1;
   if(volumeConfirm) score += 1;
   if(vonRestorffDetected || bandwagonDetected) score += 1;
   return score;
}

//+------------------------------------------------------------------+
//| Check Volume Cluster                                             |
//+------------------------------------------------------------------+
bool IsVolumeCluster(int idx, int period, double volumeMultiplier)
{
   double sumVol = 0.0;
   for(int j = idx; j < idx + period && j < iBars(_Symbol, PERIOD_CURRENT); j++)
   {
      sumVol += (double)iVolume(_Symbol, PERIOD_CURRENT, j);
   }
   double avgVol = sumVol / period;
   return (iVolume(_Symbol, PERIOD_CURRENT, idx) > volumeMultiplier * avgVol);
}

//+------------------------------------------------------------------+
//| Log Trade Result                                                 |
//+------------------------------------------------------------------+
void LogTradeResult(string comment, double entry, double sl, double tp, bool win)
{
   if(statCount >= 500) return;
   TradeStat newStat;
   newStat.t = iTime(_Symbol, PERIOD_CURRENT, 0);
   newStat.signalType = StringFind(comment, "Hook") >= 0 ? "Hook" :
                        StringFind(comment, "FS") >= 0 ? "FS" :
                        StringFind(comment, "Hybrid") >= 0 ? "Hybrid" : "Unknown";
   newStat.entry = entry;
   newStat.sl = sl;
   newStat.tp = tp;
   newStat.win = win;
   stats[statCount++] = newStat;
}

//+------------------------------------------------------------------+
//| Draw All Frequency Lines                                         |
//+------------------------------------------------------------------+
void DrawAllFreqLines()
{
   for(int i = 0; i < allFreqLineCount; i++)
      if(allFreqLines[i].isActive)
      {
         string name = "EA_Freq-" + allFreqLines[i].freqType + IntegerToString(i);
         ObjectDelete(0, name);
         ObjectCreate(0, name, OBJ_TREND, 0, allFreqLines[i].t1, allFreqLines[i].p1, allFreqLines[i].t2, allFreqLines[i].p2);
         ObjectSetInteger(0, name, OBJPROP_COLOR, allFreqLines[i].freqType == "Primary" ? clrRoyalBlue : clrMediumPurple);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Extend to future
         ObjectSetString(0, name, OBJPROP_TEXT, allFreqLines[i].freqType + "(" + IntegerToString(allFreqLines[i].touches) + ")");
      }
}

//+------------------------------------------------------------------+
//| Draw Signal Confidence                                           |
//+------------------------------------------------------------------+
void DrawSignalConfidence(Zone &z, double conf, bool isBuy)
{
   string name = "EA_" + (isBuy ? "BuyConf" : "SellConf");
   double priceLevel = z.price + (isBuy ? -10 : 10) * Point();
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), priceLevel);
   ObjectSetString(0, name, OBJPROP_TEXT, (isBuy ? "Buy " : "Sell ") + DoubleToString(conf, 1) + "/7");
   ObjectSetInteger(0, name, OBJPROP_COLOR, conf >= MinScoreThreshold ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
//| Draw Noise Warning                                               |
//+------------------------------------------------------------------+
void DrawNoiseWarning()
{
   string noiseWarnName = "EA_NoiseWarn_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, 0));
   if(ObjectFind(0, noiseWarnName) < 0)
      ObjectCreate(0, noiseWarnName, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), iHigh(_Symbol, PERIOD_CURRENT, 0) + 20 * Point());
   ObjectSetString(0, noiseWarnName, OBJPROP_TEXT, "Market structure = NOISE! Signals disabled.");
   ObjectSetInteger(0, noiseWarnName, OBJPROP_COLOR, clrOrangeRed);
}

//+------------------------------------------------------------------+
//| Draw Statistics Overlay                                          |
//+------------------------------------------------------------------+
void DrawStatOverlay()
{
   int win = 0;
   for(int i = 0; i < statCount; i++) if(stats[i].win) win++;
   double rate = (statCount > 0) ? (double)win / statCount * 100.0 : 0.0;
   string statText = StringFormat("Success: %.1f%% (%d/%d)", rate, win, statCount);
   string name = "EA_WinStatOverlay";
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, statText);
   ObjectSetInteger(0, name, OBJPROP_COLOR, rate > 50 ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 30);
}

//+------------------------------------------------------------------+
//| Analyze Signal Accuracy                                          |
//+------------------------------------------------------------------+
void AnalyzeSignalAccuracy()
{
   int hookWin = 0, hookTotal = 0;
   for(int i = 0; i < statCount; i++)
   {
      if(stats[i].signalType == "Hook")
      {
         hookTotal++;
         if(stats[i].win) hookWin++;
      }
   }
   double acc = (hookTotal > 0) ? (double)hookWin / hookTotal * 100.0 : 0.0;
   string accText = StringFormat("Hook Accuracy: %.1f%% (%d/%d)", acc, hookWin, hookTotal);
   DrawStatLabel("EA_HookAccuracyLabel", accText, 60, acc >= 60 ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
//| Check Triple Intersection Confirmation                           |
//+------------------------------------------------------------------+
bool IsTripleIntersectionConfirmed()
{
   bool freqOK = (allFreqLineCount >= 2);
   bool fibOK = (fibQuality >= MEDIUM);
   double median = UseSchiffPitchfork ? schiffMedian : pitchforkMedian;
   double lower = UseSchiffPitchfork ? schiffLower : pitchforkLower;
   double upper = UseSchiffPitchfork ? schiffUpper : pitchforkUpper;
   bool pitchOK = (median != 0 && iClose(_Symbol, PERIOD_CURRENT, 1) > lower && iClose(_Symbol, PERIOD_CURRENT, 1) < upper);
   return (freqOK && fibOK && pitchOK);
}

//+------------------------------------------------------------------+
//| Draw Triple Intersection Marker                                  |
//+------------------------------------------------------------------+
void DrawTripleIntersectionMarker()
{
   string markerName = "EA_TripleMarker_" + TimeToString(iTime(_Symbol, PERIOD_CURRENT, 1));
   ObjectCreate(0, markerName, OBJ_ARROW, 0, iTime(_Symbol, PERIOD_CURRENT, 1), iClose(_Symbol, PERIOD_CURRENT, 1));
   ObjectSetInteger(0, markerName, OBJPROP_COLOR, clrFuchsia);
   ObjectSetInteger(0, markerName, OBJPROP_ARROWCODE, 233);
   ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, markerName, OBJPROP_TEXT, "Triple Intersection");
}

//+------------------------------------------------------------------+
//| Execute Triple Intersection Trade                                |
//+------------------------------------------------------------------+
void ExecuteTripleIntersectionTrade()
{
   if(CountOpenOrders() >= MaxOpenOrders) return;

   double slBuy = iClose(_Symbol, PERIOD_CURRENT, 1) - atrCurrent * 2 * Point();
   double tpBuy = iClose(_Symbol, PERIOD_CURRENT, 1) + atrCurrent * 3 * HookTPMultiplier * Point();
   double lotBuy = CalculateDynamicLotSize((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - slBuy) / Point()) * HookLotMultiplier;
   trade.Buy(lotBuy, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), slBuy, tpBuy, "TripleBuy_Hook");
   if(statCount < 500) LogTradeResult("TripleBuy", SymbolInfoDouble(_Symbol, SYMBOL_ASK), slBuy, tpBuy, false);

   double slSell = iClose(_Symbol, PERIOD_CURRENT, 1) + atrCurrent * 2 * Point();
   double tpSell = iClose(_Symbol, PERIOD_CURRENT, 1) - atrCurrent * 3 * HookTPMultiplier * Point();
   double lotSell = CalculateDynamicLotSize((slSell - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / Point()) * HookLotMultiplier;
   trade.Sell(lotSell, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), slSell, tpSell, "TripleSell_Hook");
   if(statCount < 500) LogTradeResult("TripleSell", SymbolInfoDouble(_Symbol, SYMBOL_BID), slSell, tpSell, false);
}

//+------------------------------------------------------------------+
//| Check Volatility Asymmetry                                       |
//+------------------------------------------------------------------+
bool CheckVolatilityAsymmetry()
{
   double range = iHigh(_Symbol, PERIOD_CURRENT, 1) - iLow(_Symbol, PERIOD_CURRENT, 1);
   return (range >= 1.5 * atrCurrent);
}

//+------------------------------------------------------------------+
//| Check Smooth Flow                                                |
//+------------------------------------------------------------------+
bool CheckSmoothFlow()
{
   int higherHighs = 0, lowerLows = 0;
   for(int i = 1; i <= SmoothFlowBars && i < iBars(_Symbol, PERIOD_CURRENT) - 1; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, i) > iHigh(_Symbol, PERIOD_CURRENT, i + 1) && 
         iLow(_Symbol, PERIOD_CURRENT, i) > iLow(_Symbol, PERIOD_CURRENT, i + 1)) higherHighs++;
      if(iHigh(_Symbol, PERIOD_CURRENT, i) < iHigh(_Symbol, PERIOD_CURRENT, i + 1) && 
         iLow(_Symbol, PERIOD_CURRENT, i) < iLow(_Symbol, PERIOD_CURRENT, i + 1)) lowerLows++;
   }
   return (higherHighs >= SmoothFlowBars * 0.7 || lowerLows >= SmoothFlowBars * 0.7);
}

//+------------------------------------------------------------------+
//| Draw Objects                                                     |
//+------------------------------------------------------------------+
void DrawObjects()
{
   ObjectsDeleteAll(0, "EA_"); // Delete only EA-specific objects
   DrawZones();
   DrawZones2();
   DrawFibZone();
   DrawPivots();
   DrawMinorPivots();
   DrawMinorPitchfork();
   DrawMinorInwardParallel();
   DrawFibSquareField();
   DrawSilhouette();
   DrawMinorSupport();
   DrawFibZone2();
   DrawExpandingPivot();
   DrawOutwardFrequency();
   DrawVolatility(1);
   DrawPitchforkMedian();
   if(UseSchiffPitchfork) DrawSchiffPitchfork();
   if(EnableHookDetection) DrawHook(1);
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Zone                                              |
//+------------------------------------------------------------------+
void DrawFibZone()
{
   if(DemandZone.t == 0 || SupplyZone.t == 0) return;
   string name = "EA_FibZone";
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_FIBO, 0, DemandZone.t, DemandZone.price, SupplyZone.t, SupplyZone.price);
   }
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, FibRetraceLevel_FF);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 1.0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrPurple);
   ObjectSetString(0, name, OBJPROP_TEXT, "Fibonacci Zone");
}

//+------------------------------------------------------------------+
//| Draw Pivots                                                      |
//+------------------------------------------------------------------+
void DrawPivots()
{
   if(pivReady)
   {
      for(int i = 0; i < 2; i++)
      {
         HLine("EA_PH" + IntegerToString(i), pivHighVal[i], clrBlue, "Pivot High " + IntegerToString(i));
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Minor Pivots                                                |
//+------------------------------------------------------------------+
void DrawMinorPivots()
{
   if(pivLowReady)
   {
      for(int i = 0; i < 2; i++)
      {
         HLine("EA_PL" + IntegerToString(i), pivLowVal[i], clrOrange, "Pivot Low " + IntegerToString(i));
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Minor Pitchfork                                             |
//+------------------------------------------------------------------+
void DrawMinorPitchfork()
{
   if(!mpReady) return;
   ObjectDelete(0, "EA_MinorPF");
   ObjectCreate(0, "EA_MinorPF", OBJ_CHANNEL, 0, mpT[0], mpP[0], mpT[1], mpP[1], mpT[2], mpP[2]);
   ObjectSetInteger(0, "EA_MinorPF", OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, "EA_MinorPF", OBJPROP_TEXT, "Minor Pitchfork");
}

//+------------------------------------------------------------------+
//| Draw Minor Inward Parallel                                       |
//+------------------------------------------------------------------+
void DrawMinorInwardParallel()
{
   if(!mpReady) return;
   ObjectDelete(0, "EA_MinorPar");
   ObjectCreate(0, "EA_MinorPar", OBJ_TREND, 0, e0, ep0, e1, ep1);
   ObjectSetInteger(0, "EA_MinorPar", OBJPROP_COLOR, clrAqua);
   ObjectSetString(0, "EA_MinorPar", OBJPROP_TEXT, "Inward Parallel");

   string inwardText = "EA_InwardParallelText";
   if(ObjectFind(0, inwardText) < 0) ObjectCreate(0, inwardText, OBJ_TEXT, 0, e1, ep1 + 5 * Point());
   ObjectSetString(0, inwardText, OBJPROP_TEXT, "Inward Parallel");
   ObjectSetInteger(0, inwardText, OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0, inwardText, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, inwardText, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Square Field                                      |
//+------------------------------------------------------------------+
void DrawFibSquareField()
{
   if(ObjectFind(0, "EA_FibField") >= 0)
   {
      string fibSquareText = "EA_FibSquareText";
      if(ObjectFind(0, fibSquareText) < 0) ObjectCreate(0, fibSquareText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), (demand2.price + supply2.price) / 2);
      ObjectSetString(0, fibSquareText, OBJPROP_TEXT, "Fibonacci Square Field");
      ObjectSetInteger(0, fibSquareText, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, fibSquareText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, fibSquareText, OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Draw Silhouette                                                  |
//+------------------------------------------------------------------+
void DrawSilhouette()
{
   if(svReady)
   {
      DrawTrend("EA_SV", svT1, svP1, svT2, svP2, clrMagenta, STYLE_DASH, "Silhouette Line");
      string silhouetteText = "EA_SilhouetteText";
      if(ObjectFind(0, silhouetteText) < 0) ObjectCreate(0, silhouetteText, OBJ_TEXT, 0, svT2, svP2 + 5 * Point());
      ObjectSetString(0, silhouetteText, OBJPROP_TEXT, "Silhouette");
      ObjectSetInteger(0, silhouetteText, OBJPROP_COLOR, clrMagenta);
      ObjectSetInteger(0, silhouetteText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, silhouetteText, OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Draw Minor Support                                               |
//+------------------------------------------------------------------+
void DrawMinorSupport()
{
   if(!pivLowReady) return;
   ObjectDelete(0, "EA_MinorSupport");
   ObjectCreate(0, "EA_MinorSupport", OBJ_TREND, 0, pivLowTime[0], pivLowVal[0], pivLowTime[1], pivLowVal[1]);
   ObjectSetInteger(0, "EA_MinorSupport", OBJPROP_COLOR, clrOrange);
   ObjectSetString(0, "EA_MinorSupport", OBJPROP_TEXT, "Minor Support Line");
}

//+------------------------------------------------------------------+
//| Draw Secondary Fibonacci Zone                                    |
//+------------------------------------------------------------------+
void DrawFibZone2()
{
   if(!manipulationDetected) return;
   double lvl = EntryLevel2();
   HLine("EA_Fib612", lvl, clrCyan, "Fib Retrace 61.8%");
   HLine("EA_Fib1612", manipLevel - (manipLevel - demand2.price) * FibManipExtTarget_Omni, clrCyan, "Fib Extension 161.8%");
}

//+------------------------------------------------------------------+
//| Draw Expanding Pivot                                             |
//+------------------------------------------------------------------+
void DrawExpandingPivot()
{
   if(!expPivotReady) return;
   ObjectDelete(0, "EA_ExpPivotLine1");
   ObjectCreate(0, "EA_ExpPivotLine1", OBJ_TREND, 0, e0, ep0, e1, ep1);
   ObjectSetInteger(0, "EA_ExpPivotLine1", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "EA_ExpPivotLine1", OBJPROP_TEXT, "Expanding Pivot Line 1");

   ObjectDelete(0, "EA_ExpPivotLine2");
   ObjectCreate(0, "EA_ExpPivotLine2", OBJ_TREND, 0, e1, ep1, e2, ep2);
   ObjectSetInteger(0, "EA_ExpPivotLine2", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "EA_ExpPivotLine2", OBJPROP_TEXT, "Expanding Pivot Line 2");
}

//+------------------------------------------------------------------+
//| Draw Outward Frequency                                           |
//+------------------------------------------------------------------+
void DrawOutwardFrequency()
{
   if(!ofReady) return;
   ObjectDelete(0, "EA_OutFreqLine");
   ObjectCreate(0, "EA_OutFreqLine", OBJ_TREND, 0, ofT1, ofP1, ofT2, ofP2);
   ObjectSetInteger(0, "EA_OutFreqLine", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "EA_OutFreqLine", OBJPROP_RAY_RIGHT, true);
   ObjectSetString(0, "EA_OutFreqLine", OBJPROP_TEXT, "Outward Frequency Line");

   string outwardText = "EA_OutwardFrequencyText";
   if(ObjectFind(0, outwardText) < 0) ObjectCreate(0, outwardText, OBJ_TEXT, 0, ofT2, ofP2 + 5 * Point());
   ObjectSetString(0, outwardText, OBJPROP_TEXT, "Outward Frequency");
   ObjectSetInteger(0, outwardText, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, outwardText, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, outwardText, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Draw Pitchfork Median                                            |
//+------------------------------------------------------------------+
void DrawPitchforkMedian()
{
   if(pitchforkMedian != 0)
   {
      string medianName = "EA_PitchforkMedian";
      if(ObjectFind(0, medianName) < 0) 
         ObjectCreate(0, medianName, OBJ_HLINE, 0, 0, pitchforkMedian);
      ObjectSetDouble(0, medianName, OBJPROP_PRICE, pitchforkMedian);
      ObjectSetInteger(0, medianName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, medianName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, medianName, OBJPROP_STYLE, STYLE_DOT);

      string medianText = "EA_PitchforkMedianText";
      if(ObjectFind(0, medianText) < 0) 
         ObjectCreate(0, medianText, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), pitchforkMedian + 5 * Point());
      ObjectSetInteger(0, medianText, OBJPROP_TIME, iTime(_Symbol, PERIOD_CURRENT, 0));
      ObjectSetDouble(0, medianText, OBJPROP_PRICE, pitchforkMedian + 5 * Point());
      ObjectSetString(0, medianText, OBJPROP_TEXT, "Pitchfork Median");
      ObjectSetInteger(0, medianText, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, medianText, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, medianText, OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Draw Volatility                                                  |
//+------------------------------------------------------------------+
void DrawVolatility(int idx)
{
   DetectVolatility(idx); // Calls the updated function with prefixed object names
}

//+------------------------------------------------------------------+
//| Draw Horizontal Line                                             |
//+------------------------------------------------------------------+
void HLine(string name, double price, color clr, string text)
{
   string fullName = "EA_" + name;
   ObjectDelete(0, fullName);
   ObjectCreate(0, fullName, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullName, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Draw Trend Line                                                  |
//+------------------------------------------------------------------+
void DrawTrend(string name, datetime t1, double p1, datetime t2, double p2, color clr, int style, string text)
{
   string fullName = "EA_" + name;
   ObjectDelete(0, fullName);
   ObjectCreate(0, fullName, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_STYLE, style);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Log Signal Statistics                                            |
//+------------------------------------------------------------------+
void LogSignalStat(string type, bool win, double rr, datetime entryT, double entryP, datetime exitT, double exitP)
{
   if(signalStatCount >= 100) return;
   signalStats[signalStatCount].signalType = type;
   signalStats[signalStatCount].win = win;
   signalStats[signalStatCount].rrAchieved = rr;
   signalStats[signalStatCount].entryTime = entryT;
   signalStats[signalStatCount].entryPrice = entryP;
   signalStats[signalStatCount].exitTime = exitT;
   signalStats[signalStatCount].exitPrice = exitP;
   signalStatCount++;
}

//+------------------------------------------------------------------+
//| Draw Signal Statistics                                           |
//+------------------------------------------------------------------+
void DrawSignalStats()
{
   int hookWin = 0, hookTotal = 0, fsWin = 0, fsTotal = 0, hybridWin = 0, hybridTotal = 0;
   int winCount = 0, lossCount = 0;
   
   for(int i = 0; i < signalStatCount; i++)
   {
      if(signalStats[i].signalType == "Hook")
      {
         hookTotal++;
         if(signalStats[i].win) hookWin++;
      }
      else if(signalStats[i].signalType == "FS")
      {
         fsTotal++;
         if(signalStats[i].win) fsWin++;
      }
      else if(signalStats[i].signalType == "Hybrid")
      {
         hybridTotal++;
         if(signalStats[i].win) hybridWin++;
      }
      
      if(signalStats[i].win) winCount++;
      else lossCount++;
   }
   
   double hookWinRate = (hookTotal > 0) ? (double)hookWin / hookTotal * 100.0 : 0.0;
   double fsWinRate = (fsTotal > 0) ? (double)fsWin / fsTotal * 100.0 : 0.0;
   double hybridWinRate = (hybridTotal > 0) ? (double)hybridWin / hybridTotal * 100.0 : 0.0;
   double overallWinRate = (winCount + lossCount > 0) ? (double)winCount / (winCount + lossCount) * 100.0 : 0.0;
   
   string hookText = StringFormat("Hook: %.1f%% win", hookWinRate);
   string fsText = StringFormat("FS: %.1f%% win", fsWinRate);
   string hybridText = StringFormat("Hybrid: %.1f%% win", hybridWinRate);
   string overallText = StringFormat("Overall: %.1f%% win", overallWinRate);
   
   DrawStatLabel("EA_HookStat", hookText, 20, clrWhite);
   DrawStatLabel("EA_FSStat", fsText, 40, clrWhite);
   DrawStatLabel("EA_HybridStat", hybridText, 60, clrWhite);
   DrawStatLabel("EA_OverallStat", overallText, 80, clrWhite);
}

//+------------------------------------------------------------------+
//| Draw Statistics Label                                            |
//+------------------------------------------------------------------+
void DrawStatLabel(string name, string text, int yOffset, color col)
{
   string statLabelName = "EA_StatLabel_" + name;
   if(ObjectFind(0, statLabelName) < 0)
   {
      ObjectCreate(0, statLabelName, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, statLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, statLabelName, OBJPROP_YDISTANCE, yOffset);
   ObjectSetString(0, statLabelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, statLabelName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, statLabelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, statLabelName, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| End of Code                                                      |
//+------------------------------------------------------------------+