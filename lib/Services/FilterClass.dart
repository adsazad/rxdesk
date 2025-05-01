import 'dart:math';


class FilterClass {
  static const double PIE = 3.14159;

  static const int MAX_GAIN_INDEX = 6; //0.25,0.5,1.0,2.0,4.0,8.0 cm/mV
  static const int MAX_OLD_SPEED_INDEX = 12; //5,6.25,12.5,25,50,100 mm/sec
  static const int MAX_SPEED_INDEX = 9; //1,2,5,10,20,30,50,75,100
  static const int MAX_LPF_INDEX = 13; //10,15,20,35,70,100,150 Hz
  static const int MAX_HPF_INDEX = 9; //0.05,0.1,0.2,0.3,0.6,0.8,1.0 Hz
  static const int MAX_NOTCH_INDEX = 2; //NotchOFF, NotchON
  static const int MAX_SRATE_INDEX = 10; //64,128,256,1K,2K,4K,8K,10K,20K,400K
  static const int MAX_RANGE_INDEX = 10; //10V ,5V, 2V, 1V, 500mv, 100 mv,50mv,10mv,5mv, 1mv

  static const int MAX_STAGES = 3;
  static const int HPF_STAGE = 0;
  static const int LPF_STAGE = 1;
  static const int NOTCH_STAGE = 2;
  // static const int LPF_STAGE2 = 3;


  List<double> CF = List<double>.filled(5, 0, growable: false);
  List<List<double>> Coeff = List.generate(
      MAX_STAGES, (i) => List.generate(5, (j) => 0));
  int SpeedSkips = 0;
  double GainFactor = 0;
  double RangeValue = 0;

  double alpha = 0;
  double beta = 0;
  double gamma = 0;
  double theta = 0;
  int mLPFInd = 0;
  int mHPFInd = 0;
  int mNotchInd = 0;
  int mSpeedInd = 0;
  int mGainInd = 0;
  int mLineFreqInd = 0;
  int mSRateInd = 0;
  bool mUseOldSpeeds = false;
  int mRangeInd = 0;

  List<double> mLPFVal = List<double>.filled(MAX_LPF_INDEX, 0);
  List<double> mHPFVal = List<double>.filled(MAX_HPF_INDEX, 0);
  List<double> mNotchVal = List<double>.filled(MAX_NOTCH_INDEX, 0);
  List<double> mSpeedVal = List<double>.filled(MAX_SPEED_INDEX, 0);
  List<double> mOldSpeedVal = List<double>.filled(MAX_OLD_SPEED_INDEX, 0);
  List<double> mGainVal = List<double>.filled(MAX_GAIN_INDEX, 0);
  List<double> mRangeVal = List<double>.filled(MAX_RANGE_INDEX, 0);
  List<int> mRangeHwVal0 = List<int>.filled(MAX_RANGE_INDEX, 0);
  List<int> mRangeHwVal1 = List<int>.filled(MAX_RANGE_INDEX, 0);

  List<double> mSRateVal = List<double>.filled(MAX_SRATE_INDEX, 0);

  List<String> mLPFCaptions = List<String>.filled(MAX_LPF_INDEX, "");
  List<String> mHPFCaptions = List<String>.filled(MAX_HPF_INDEX, "");
  List<String> mNotchCaptions = List<String>.filled(MAX_NOTCH_INDEX, "");
  List<String> mSpeedCaptions = List<String>.filled(MAX_SPEED_INDEX, "");
  List<String> mOldSpeedCaptions = List<String>.filled(MAX_OLD_SPEED_INDEX, "");
  List<String> mGainCaptions = List<String>.filled(MAX_GAIN_INDEX, "");
  List<String> mSRateCaptions = List<String>.filled(MAX_SRATE_INDEX, "");
  List<String> mRangeCaptions = List<String>.filled(MAX_RANGE_INDEX, "");

  int mSR = 0;
  double mPixels1mmY = 0;
  double mCountPermV = 0;

  double mConverionOut = 0;

  init(int pSR, int pLPFInd, int pHPFInd, int pNotchInd, int pGainInd,
      int pSpeedInd, double pCountPermV, double pPixels1mmY, int pLineFreqInd,
      int pRangeInd, [int pSRInd = -1, bool pUseOldSpeeds = false]) {
    // print("INIT FILTER A");
    InitCaptionsAndValue();
    mSR = pSR;
    mUseOldSpeeds = pUseOldSpeeds;
    //If pSRInd > -1 Then mSR = mSRateVal(pSRInd)
    mPixels1mmY = pPixels1mmY;
    mCountPermV = pCountPermV;
    mLineFreqInd = pLineFreqInd;
    // print("pLPF");
    // print(pLPFInd);
    // print(pHPFInd);

    mLPFInd = pLPFInd - 1;
    // mLPFVal = pLPFInd;
    AdjustLPF(true);
    mHPFInd = pHPFInd - 1;
    AdjustHPF(true);
    // pNotchInd = 1;
    // print("Notch Ind ${pNotchInd}");
    mNotchInd = pNotchInd;
    AdjustNotch(true);
    mGainInd = pGainInd - 1;
    AdjustGain(true);
    mSpeedInd = pSpeedInd - 1;
    AdjustSpeed(true);
    mRangeInd = pRangeInd - 1;
    AdjustRange(true);
  }

  FilterClass() {
    InitCaptionsAndValue();
    // mSR = 1000;
    // mPixels1mmY = 10;
    // mCountPermV = 10;
    // mLineFreqInd = 0;
    // mLPFInd = 0; AdjustLPF(true);
    // mHPFInd = 0; AdjustHPF(true);
    // mNotchInd = 0; AdjustNotch(true);
    // mGainInd = 0; AdjustGain(true);
    // mSpeedInd = 0; AdjustSpeed(true);
    // mRangeInd = -1; AdjustRange(true);
  }

  void InitCaptionsAndValue() {
    //SR 500
    //mOldSpeedVal[0] = 2000; mOldSpeedVal[1] = 1000; mOldSpeedVal[2] = 500;
    //mOldSpeedVal[3] = 200; mOldSpeedVal[4] = 100; mOldSpeedVal[5] = 50;
    //mOldSpeedVal[6] = 20; mOldSpeedVal[7] = 10; mOldSpeedVal[8] = 5;
    //mOldSpeedVal[9] = 4; mOldSpeedVal[10] = 2; mOldSpeedVal[11] = 1;

    //SR 250
    mOldSpeedVal[0] = 1000;
    mOldSpeedVal[1] = 500;
    mOldSpeedVal[2] = 200;
    mOldSpeedVal[3] = 100;
    mOldSpeedVal[4] = 50;
    mOldSpeedVal[5] = 20;
    mOldSpeedVal[6] = 10;
    mOldSpeedVal[7] = 5;
    mOldSpeedVal[8] = 4;
    mOldSpeedVal[9] = 2;
    mOldSpeedVal[10] = 1;
    mOldSpeedVal[11] = 1;

    mOldSpeedCaptions[0] = "0.05 div/sec";
    mOldSpeedCaptions[1] = "0.1 div/sec";
    mOldSpeedCaptions[2] = "0.2 div/sec";
    mOldSpeedCaptions[3] = "0.5 div/sec";
    mOldSpeedCaptions[4] = "1 div/sec";
    mOldSpeedCaptions[5] = "2 div/sec";
    mOldSpeedCaptions[6] = "5 div/sec";
    mOldSpeedCaptions[7] = "10 div/sec";
    mOldSpeedCaptions[8] = "20 div/sec";
    mOldSpeedCaptions[9] = "25 div/sec";
    mOldSpeedCaptions[10] = "50 div/sec";
    mOldSpeedCaptions[11] = "100 div/sec";

    mSpeedVal[0] = 1;
    mSpeedVal[1] = 2;
    mSpeedVal[2] = 5;
    mSpeedVal[3] = 10;
    mSpeedVal[4] = 20;
    mSpeedVal[5] = 30;
    mSpeedVal[6] = 50;
    mSpeedVal[7] = 75;
    mSpeedVal[8] = 100;

    mSpeedCaptions[0] = "1:1";
    mSpeedCaptions[1] = "1:2";
    mSpeedCaptions[2] = "1:5";
    mSpeedCaptions[3] = "1:10";
    mSpeedCaptions[4] = "1:20";
    mSpeedCaptions[5] = "1:30";
    mSpeedCaptions[6] = "1:50";
    mSpeedCaptions[7] = "1:75";
    mSpeedCaptions[8] = "1:100";


    mGainVal[0] = 0.25;
    mGainVal[1] = 0.5;
    mGainVal[2] = 1;
    mGainVal[3] = 2;
    mGainVal[4] = 4;
    mGainVal[5] = 8;

    mGainCaptions[0] = "2.5 mm/mV";
    mGainCaptions[1] = "5 mm/mV";
    mGainCaptions[2] = "10 mm/mV";
    mGainCaptions[3] = "20 mm/mV";
    mGainCaptions[4] = "40 mm/mV";
    mGainCaptions[5] = "80 mm/mV";

    mLPFVal[0] = 10;
    mLPFVal[1] = 15;
    mLPFVal[2] = 20;
    mLPFVal[3] = 35;
    mLPFVal[4] = 70;
    mLPFVal[5] = 100;
    mLPFVal[6] = 150;
    mLPFVal[7] = 5;
    mLPFVal[8] = 2;
    mLPFVal[9] = 1;
    // 12hz
    mLPFVal[10] = 12;
    mLPFVal[11] = 40;
    mLPFVal[12] = 0.5;

    mLPFCaptions[0] = "10 Hz";
    mLPFCaptions[1] = "15 Hz";
    mLPFCaptions[2] = "20 Hz";
    mLPFCaptions[3] = "35 Hz";
    mLPFCaptions[4] = "70 Hz";
    mLPFCaptions[5] = "100 Hz";
    mLPFCaptions[6] = "150 Hz";
    mLPFCaptions[7] = "5 Hz";
    mLPFCaptions[8] = "2 Hz";
    mLPFCaptions[9] = "1 Hz";
    mLPFCaptions[10] = "12 Hz";
    mLPFCaptions[11] = "40 Hz";
    mLPFCaptions[12] = "0.5 Hz";

    mHPFVal[0] = 0;
    mHPFVal[1] = 0.05;
    mHPFVal[2] = 0.1;
    mHPFVal[3] = 0.2;
    mHPFVal[4] = 0.3;
    mHPFVal[5] = 0.6;
    mHPFVal[6] = 0.81;
    mHPFVal[7] = 1;
    // 5 hz
    mHPFVal[8] = 5;

    mHPFCaptions[0] = "DC";
    mHPFCaptions[1] = "0.05 Hz";
    mHPFCaptions[2] = "0.1 Hz";
    mHPFCaptions[3] = "0.2 Hz";
    mHPFCaptions[4] = "0.3 Hz";
    mHPFCaptions[5] = "0.6 Hz";
    mHPFCaptions[6] = "0.8 Hz";
    mHPFCaptions[7] = "1.0 Hz";

    mNotchVal[0] = 0;
    mNotchVal[1] = 1;
    mNotchCaptions[0] = "Notch OFF";
    mNotchCaptions[1] = "Notch ON";

    mSRateVal[0] = 64;
    mSRateVal[1] = 128;
    mSRateVal[2] = 256;
    mSRateVal[3] = 1000;
    mSRateVal[4] = 2000;
    mSRateVal[5] = 4000;
    mSRateVal[6] = 8000;
    mSRateVal[7] = 10000;
    mSRateVal[8] = 20000;
    mSRateVal[9] = 400000;

    mSRateCaptions[0] = "64";
    mSRateCaptions[1] = "128";
    mSRateCaptions[2] = "256";
    mSRateCaptions[3] = "1K";
    mSRateCaptions[4] = "2K";
    mSRateCaptions[5] = "4K";
    mSRateCaptions[6] = "8K";
    mSRateCaptions[7] = "10K";
    mSRateCaptions[8] = "20K";
    mSRateCaptions[9] = "400K";


    mRangeVal[0] = 10;
    mRangeVal[1] = 5;
    mRangeVal[2] = 2;
    mRangeVal[3] = 1;
    mRangeVal[4] = 0.5;
    mRangeVal[5] = 0.1;
    mRangeVal[6] = 0.05;
    mRangeVal[7] = 0.01;
    mRangeVal[8] = 0.005;
    mRangeVal[9] = 0.001;
    //mRangeVal[6] = 0.05; mRangeVal[7] = 0.01; mRangeVal[8] = 0.005; mRangeVal[9] = 0.001;

    //1298 Hw Type 0
    mRangeHwVal0[0] = 1;
    mRangeHwVal0[1] = 2;
    mRangeHwVal0[2] = 3;
    mRangeHwVal0[3] = 4;
    mRangeHwVal0[4] = 0;
    mRangeHwVal0[5] = 5;
    mRangeHwVal0[6] = 6;
    mRangeHwVal0[7] = 6;
    mRangeHwVal0[8] = 6;
    mRangeHwVal0[9] = 6;
    //1299 HW Type 1
    mRangeHwVal1[0] = 0;
    mRangeHwVal1[1] = 1;
    mRangeHwVal1[2] = 2;
    mRangeHwVal1[3] = 3;
    mRangeHwVal1[4] = 4;
    mRangeHwVal1[5] = 5;
    mRangeHwVal1[6] = 6;
    mRangeHwVal1[7] = 6;
    mRangeHwVal1[8] = 6;
    mRangeHwVal1[9] = 6;

    mRangeCaptions[0] = "10 V";
    mRangeCaptions[1] = "5 V";
    mRangeCaptions[2] = "2 V";
    mRangeCaptions[3] = "1 V";
    mRangeCaptions[4] = "500 mV";
    mRangeCaptions[5] = "100 mV";
    mRangeCaptions[6] = "50 mV";
    mRangeCaptions[7] = "10 mV";
    mRangeCaptions[8] = "5 mV";
    mRangeCaptions[9] = "1 mV";
  }

  LowPassVal(int index) {
    return mLPFVal[index];
  }

  HighPassVal(int index) {
    return mHPFVal[index];
  }

  LowPassIndexFromVal(double val) {
    for (int i = 0; i < MAX_LPF_INDEX; i++) {
      if (mLPFVal[i] == val) {
        return i;
      }
    }
    return 0;
  }

  HighPassFilterIndexFromVal(double val) {
    for (int i = 0; i < MAX_HPF_INDEX; i++) {
      if (mHPFVal[i] == val) {
        return i;
      }
    }
    return 0;
  }

  int get SRateMaxInd {
    return MAX_SRATE_INDEX;
  }

  int get LPFMaxInd {
    return MAX_LPF_INDEX;
  }

  int get HPFMaxInd {
    return MAX_HPF_INDEX;
  }

  int get NotchMaxInd {
    return MAX_NOTCH_INDEX;
  }

  int get GainMaxInd {
    return MAX_GAIN_INDEX;
  }

  int get SpeedMaxInd {
    if (mUseOldSpeeds == false) {
      return MAX_SPEED_INDEX;
    }
    else {
      return MAX_OLD_SPEED_INDEX;
    }
  }

  int get RangeMaxInd {
    return MAX_RANGE_INDEX;
  }

  int get LPFInd {
    return mLPFInd;
  }

  set LPFInd(int value) {
    mLPFInd = value;
    // LP2(mLPFVal[mLPFInd], mSR.toDouble(),0.6);
    LP1(mLPFVal[mLPFInd], mSR.toDouble());
    for (int i = 0; i < 5; i++) {
      Coeff[LPF_STAGE][i] = CF[i];
    }
  }

  int get HPFInd {
    return mHPFInd;
  }

  set HPFInd(int value) {
    mHPFInd = value;
    HP1(mHPFVal[mHPFInd], mSR.toDouble());
    for (int i = 0; i < 5; i++) {
      Coeff[HPF_STAGE][i] = CF[i];
    }
  }

  int get NotchInd {
    return mNotchInd;
  }

  set NotchInd(int value) {
    mNotchInd = value;
    if (mNotchInd == 0) {
      Coeff[NOTCH_STAGE][0] = 1 / 2;
      for (int i = 1; i < 5; i++) {
        Coeff[NOTCH_STAGE][i] = 0;
      }
    }
    else {
      // if(mLineFreqInd == 0) //50 Hz
      //     {
      BS2(50, mSR.toDouble(), 15);
      // }
      // else //60 Hz
      //     {
      //   BS2(60, mSR.toDouble(), 10);
      // }
      for (int i = 0; i < 5; i++) {
        Coeff[NOTCH_STAGE][i] = CF[i];
      }
    }
  }

  int get GainInd {
    return mGainInd;
  }

  set GainInd(int value) {
    mGainInd = value;
    GainFactor = mGainVal[mGainInd] * mPixels1mmY / mCountPermV;
  }

  int get SpeedInd {
    return mSpeedInd;
  }

  set SpeedInd(int value) {
    mSpeedInd = value;
    SpeedSkips = mSpeedVal[mSpeedInd].toInt();
  }

  int get SRateInd {
    return mSRateInd;
  }

  set SRateInd(int value) {
    mSRateInd = value;
  }

  int get RangeInd {
    return mRangeInd;
  }

  set RangeInd(int value) {
    mRangeInd = value;
    RangeValue = mRangeVal[RangeInd];
  }

  int RangeHwVal0(int Index) {
    return mRangeHwVal0[Index];
  }

  int RangeHwVal1(int Index) {
    return mRangeHwVal1[Index];
  }

  int get LineFrequencyInd {
    return mLineFreqInd;
  }

  set LineFrequencyInd(int value) {
    if (value == 0 || value == 1) {
      mLineFreqInd = value;
    }
    else {
      mLineFreqInd = 0;
    }
  }

  String LPFCaption(int Ind) {
    if (Ind > MAX_LPF_INDEX - 1) {
      Ind = MAX_LPF_INDEX - 1;
    }
    if (Ind < 0) {
      Ind = 0;
    }
    return mLPFCaptions[Ind];
  }

  String HPFCaption(int Ind) {
    if (Ind > MAX_HPF_INDEX - 1) {
      Ind = MAX_HPF_INDEX - 1;
    }
    if (Ind < 0) {
      Ind = 0;
    }
    return mHPFCaptions[Ind];
  }

  String NotchCaption(int Ind) {
    if (Ind > MAX_NOTCH_INDEX - 1) {
      Ind = MAX_NOTCH_INDEX - 1;
    }
    if (Ind < 0) {
      Ind = 0;
    }
    return mNotchCaptions[Ind];
  }

  String GainCaption(int Ind) {
    if (Ind > MAX_GAIN_INDEX - 1) {
      Ind = MAX_GAIN_INDEX - 1;
    }
    if (Ind < 0) {
      Ind = 0;
    }
    return mGainCaptions[Ind];
  }

  String RangeCaption(int Ind) {
    if (Ind > MAX_RANGE_INDEX - 1) {
      Ind = MAX_RANGE_INDEX - 1;
    }
    if (Ind < 0) {
      Ind = 0;
    }
    return mRangeCaptions[Ind];
  }

  String SpeedCaption(int Ind) {
    if (mUseOldSpeeds == false) {
      if (Ind > MAX_SPEED_INDEX - 1) {
        Ind = MAX_SPEED_INDEX - 1;
      }
      if (Ind < 0) {
        Ind = 0;
      }
      return mSpeedCaptions[Ind];
    }
    else {
      if (Ind > MAX_OLD_SPEED_INDEX - 1) {
        Ind = MAX_OLD_SPEED_INDEX - 1;
      }
      if (Ind < 0) {
        Ind = 0;
      }
      return mOldSpeedCaptions[Ind];
    }
  }

  String SRateCaption(int Ind) {
    if (Ind > MAX_SRATE_INDEX - 1) {
      Ind = MAX_SRATE_INDEX - 1;
    }
    if (Ind < 0) {
      Ind = 0;
    }
    return mSRateCaptions[Ind];
  }

  void AdjustLPF([bool UP = true]) {
    if (UP) {
      if (mLPFInd < (MAX_LPF_INDEX - 1)) {
        mLPFInd = (mLPFInd + 1);
      }
    }
    else {
      if (mLPFInd > 0) {
        mLPFInd = (mLPFInd - 1);
      }
    }
    // LP2(mLPFVal[mLPFInd], mSR.toDouble(),0.6);
    LP1(mLPFVal[mLPFInd], mSR.toDouble());
    for (int i = 0; i < 5; i ++) {
      Coeff[LPF_STAGE][i] = CF[i];
    }
  }

  void AdjustLPFByVal(int LpfInd) {
    if (LpfInd > (MAX_LPF_INDEX - 1)) {
      LpfInd = MAX_LPF_INDEX - 1;
    }
    if (LpfInd < 0) {
      LpfInd = 0;
    }
    mLPFInd = LpfInd;
    LP1(mLPFVal[mLPFInd], mSR.toDouble());
    for (int i = 0; i < 5; i++) {
      Coeff[LPF_STAGE][i] = CF[i];
    }
  }


  void AdjustHPF([bool UP = true]) {
    if (UP) {
      if (mHPFInd < (MAX_HPF_INDEX - 1)) {
        mHPFInd = (mHPFInd + 1);
      }
    }
    else {
      if (mHPFInd > 0) {
        mHPFInd = (mHPFInd - 1);
      }
    }

    HP1(mHPFVal[mHPFInd], mSR.toDouble());
    for (int i = 0; i < 5; i++) {
      Coeff[HPF_STAGE][i] = CF[i];
    }
  }

  void AdjustHPFByVal(int HpfInd) {
    if (HpfInd > (MAX_HPF_INDEX - 1)) {
      HpfInd = MAX_HPF_INDEX - 1;
    }
    if (HpfInd < 0) {
      HpfInd = 0;
    }
    mHPFInd = HpfInd;
    HP1(mHPFVal[mHPFInd], mSR.toDouble());
    for (int i = 0; i < 5; i++) {
      Coeff[HPF_STAGE][i] = CF[i];
    }
  }

  void AdjustNotch([bool UP = true]) {
    // if (UP)
    // {
    //   if (mNotchInd < (MAX_NOTCH_INDEX - 1))
    //   {
    //     mNotchInd = (mNotchInd + 1);
    //   }
    // }
    // else
    // {
    //   if (mNotchInd > 0)
    //   {
    //     mNotchInd = (mNotchInd - 1);
    //   }
    // }
    //HP1(mHPFVal(mNotchInd), mSR)
    if (mNotchInd == 0) {
      Coeff[NOTCH_STAGE][0] = 1 / 2;
      for (int i = 1; i < 5; i++) {
        Coeff[NOTCH_STAGE][i] = 0;
      }
    }
    else {
      // if (mLineFreqInd == 0) //50 Hz
      //     {
      // print("Notch 50");
      // print(mNotchInd);
      BS2(50, mSR.toDouble(), 10);
      // }
      // else //60 Hz
      //     {
      //   print("HPF 60");
      //
      //   BS2(60, mSR.toDouble(), 10);
      // }
      for (int i = 0; i < 5; i++) {
        Coeff[NOTCH_STAGE][i] = CF[i];
      }
    }
  }

  void AdjustNotchByVal(int NotchInd) {
    if (NotchInd > (MAX_NOTCH_INDEX - 1)) {
      NotchInd = MAX_NOTCH_INDEX - 1;
    }
    if (NotchInd < 0) {
      NotchInd = 0;
    }
    mNotchInd = NotchInd;
    if (mNotchInd == 0) {
      Coeff[NOTCH_STAGE][0] = 1 / 2;
      for (int i = 1; i < 5; i++) {
        Coeff[NOTCH_STAGE][i] = 0;
      }
    }
    else {
      if (mLineFreqInd == 0) //50 Hz
          {
        BS2(50, mSR.toDouble(), 10);
      }
      else //60 Hz
          {
        BS2(60, mSR.toDouble(), 10);
      }
      for (int i = 0; i < 5; i++) {
        Coeff[NOTCH_STAGE][i] = CF[i];
      }
    }
  }

  void AdjustSpeed([bool UP = true]) {
    if (mUseOldSpeeds == false) {
      if (UP) {
        if (mSpeedInd < (MAX_SPEED_INDEX - 1)) {
          mSpeedInd = (mSpeedInd + 1);
        }
      }
      else {
        if (mSpeedInd > 0) {
          mSpeedInd = (mSpeedInd - 1);
        }
      }
      SpeedSkips = mSpeedVal[mSpeedInd].toInt();
    }
    else {
      if (UP) {
        if (mSpeedInd < (MAX_OLD_SPEED_INDEX - 1)) {
          mSpeedInd = (mSpeedInd + 1);
        }
      }
      else {
        if (mSpeedInd > 0) {
          mSpeedInd = (mSpeedInd - 1);
        }
      }
      SpeedSkips = mOldSpeedVal[mSpeedInd].toInt();
    }
  }

  void AdjustSpeedByVal(int SpeedInd) {
    if (mUseOldSpeeds == false) {
      if (SpeedInd > (MAX_SPEED_INDEX - 1)) {
        SpeedInd = MAX_SPEED_INDEX - 1;
      }

      if (SpeedInd < 0) {
        SpeedInd = 0;
      }

      mSpeedInd = SpeedInd;
      SpeedSkips = mSpeedVal[mSpeedInd].toInt();
    }
    else {
      if (SpeedInd > (MAX_OLD_SPEED_INDEX - 1)) {
        SpeedInd = MAX_OLD_SPEED_INDEX - 1;
      }
      if (SpeedInd < 0) {
        SpeedInd = 0;
      }
      mSpeedInd = SpeedInd;
      SpeedSkips = mOldSpeedVal[mSpeedInd].toInt();
    }
  }

  void AdjustRange([bool UP = true]) {
    if (UP) {
      if (mRangeInd < (MAX_RANGE_INDEX - 1)) {
        mRangeInd = (mRangeInd + 1);
      }
    }
    else {
      if (mRangeInd > 0) {
        mRangeInd = (mRangeInd - 1);
      }
    }
    RangeValue = mRangeVal[mRangeInd];
  }

  void AdjustRangeByVal(int pRangeInd) {
    if (pRangeInd > (MAX_RANGE_INDEX - 1)) {
      pRangeInd = MAX_RANGE_INDEX - 1;
    }
    if (pRangeInd < 0) {
      pRangeInd = 0;
    }
    mRangeInd = pRangeInd;
    RangeValue = mRangeVal[pRangeInd];
  }

  void AdjustGain([bool UP = true]) {
    if (UP) {
      if (mGainInd < (MAX_GAIN_INDEX - 1)) {
        mGainInd = (mGainInd + 1);
      }
    }
    else {
      if (mGainInd > 0) {
        mGainInd = (mGainInd - 1);
      }
    }
    GainFactor = mGainVal[mGainInd] * mPixels1mmY / mCountPermV;
  }

  void AdjustGainByVal(int GainInd) {
    if (GainInd > (MAX_GAIN_INDEX - 1)) {
      GainInd = MAX_GAIN_INDEX - 1;
    }
    if (GainInd < 0) {
      GainInd = 0;
    }
    mGainInd = GainInd;
    GainFactor = mGainVal[mGainInd] * mPixels1mmY / mCountPermV;
  }

  double GetConversionOutput(double V1, double V2, double C1, double C2,
      double NewVolt) {
    mConverionOut = (((C2 - C1) / (V2 - V1)) * NewVolt) +
        (C1 - (((C2 - C1) / (V2 - V1)) * V1));
    return mConverionOut;
  }

  //Design digital filter. Single stage RC filters
  //Low Pass Filter {Yn=(1-K)*Xn+K*Yn-1}

  //VarLpfCoeff = 1# - (2.717282 ^ (-2 * PI * lpfList(currSet.LPFInd) / SR))
  void LP1(double Fc, double Fs) {
    num K;
    K = pow(2.717282, (-2 * PIE * Fc / Fs));
    CF[0] = (1 - K) / 2;
    CF[1] = K / 2;
    CF[2] = 0;
    CF[3] = 0;
    CF[4] = 0;
  }

  //High Pass Filter {Yn=k*(Xn+Yn-Xn-1)}
  void HP1(double Fc, double Fs) {
    num K;
    K = pow(2.717282, (-2 * PIE * Fc / Fs));
    CF[0] = K / 2;
    CF[1] = K / 2;
    CF[2] = -K / 2;
    CF[3] = 0;
    CF[4] = 0;
  }

  //Design digital filter. 2nd order IIR
  //2ND ORDER LOWPASS FILTER
  void LP2(double Fc, double Fs, double d) {
    theta = (2 * PIE * Fc) / Fs;
    beta = (0.5) * (1 - (d / 2.0) * sin(theta)) / (1 + (d / 2.0) * sin(theta));
    gamma = (0.5 + beta) * cos(theta);
    alpha = (0.5 + beta - gamma) / 4;
    CF[0] = alpha;
    CF[1] = gamma;
    CF[2] = 2 * alpha;
    CF[3] = -beta;
    CF[4] = CF[0];
  }

  //2ND ORDER HIGHPASS FILTER
  void HP2(double Fc, double Fs, double d) {
    theta = (2 * PIE * Fc) / Fs;
    beta = (0.5) * (1 - (d / 2.0) * sin(theta)) / (1 + (d / 2.0) * sin(theta));
    gamma = (0.5 + beta) * cos(theta);
    alpha = (0.5 + beta + gamma) / 4;
    CF[0] = alpha;
    CF[1] = gamma;
    CF[2] = -2 * alpha;
    CF[3] = -beta;
    CF[4] = CF[0];
  }

  //2ND ORDER BANDPASS Filter
  void BP2(double Fc, double Fs, double Q) {
    theta = (2 * PIE * Fc) / Fs;
    beta = (0.5) * (1 - tan(theta / (2 * Q))) / (1 + tan(theta / (2 * Q)));
    alpha = (0.5 - beta) / 2;
    gamma = (0.5 + beta) * cos(theta);
    CF[0] = alpha;
    CF[1] = gamma;
    CF[2] = 0;
    CF[3] = -beta;
    CF[4] = -CF[0];
  }

  //2ND ORDER BANDSTOP FILTER
  void BS2(double Fc, double Fs, double Q) {
    // print("BS2");
    // print("FC");
    // print(Fc);
    // print("FS");
    // print(Fs);
    // print("Q");
    // print(Q);
    theta = (2 * PIE * Fc) / Fs;
    beta = (0.5) * (1 - tan(theta / (2 * Q))) / (1 + tan(theta / (2 * Q)));
    gamma = (0.5 + beta) * cos(theta);
    alpha = (0.5 + beta) / 2;

    CF[0] = alpha;
    CF[1] = gamma;
    CF[2] = -2 * alpha * cos(theta);
    CF[3] = -beta;
    CF[4] = CF[0];

  }
}