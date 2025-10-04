class DetrendingRR{

  List<double> detrend(List<double> rrIntervals, int order){
    if (order == 1) {
      return detrendFirstOrder(rrIntervals);
    } else if (order == 2) {
      return detrendSecondOrder(rrIntervals);
    } else {
      return detrendSmooth(rrIntervals, 100);
    }
  }

  List<double> detrendFirstOrder(List<double> rrIntervals) {
    double meanX = 0, meanY = 0, num = 0, den = 0;
    int n = rrIntervals.length;

    for (int i = 0; i < n; i++) {
      meanX += i;
      meanY += rrIntervals[i];
    }
    meanX /= n;
    meanY /= n;

    for (int i = 0; i < n; i++) {
      num += (i - meanX) * (rrIntervals[i] - meanY);
      den += (i - meanX) * (i - meanX);
    }

    double slope = num / den;
    double intercept = meanY - slope * meanX;

    return List<double>.generate(n, (i) => rrIntervals[i] - (slope * i + intercept));
  }

  List<double> detrendSecondOrder(List<double> rrIntervals) {
    int n = rrIntervals.length;
    double sumX = 0, sumX2 = 0, sumX3 = 0, sumX4 = 0;
    double sumY = 0, sumXY = 0, sumX2Y = 0;

    for (int i = 0; i < n; i++) {
      double x = (i - n / 2) / n;  // Normalizing the range of x
      double y = rrIntervals[i];
      sumX += x;
      sumX2 += x * x;
      sumX3 += x * x * x;
      sumX4 += x * x * x * x;
      sumY += y;
      sumXY += x * y;
      sumX2Y += x * x * y;
    }

    double denominator = n * sumX2 * sumX4 + 2 * sumX * sumX2 * sumX3 - sumX2 * sumX2 * sumX2 - n * sumX3 * sumX3 - sumX * sumX * sumX4;
    double a = (sumY * sumX2 * sumX4 + sumXY * sumX3 * sumX2 + sumX2Y * sumX * sumX2 - sumX2Y * sumX2 * sumX2 - sumY * sumX3 * sumX3 - sumXY * sumX * sumX4) / denominator;
    double b = (n * sumXY * sumX4 + sumY * sumX3 * sumX2 + sumX * sumX2Y * sumX2 - sumX2 * sumXY * sumX2 - n * sumX2Y * sumX3 - sumY * sumX * sumX4) / denominator;
    double c = (n * sumX2 * sumX2Y + sumX * sumX2 * sumY + sumX * sumX3 * sumXY - sumY * sumX2 * sumX2 - sumX * sumX * sumX2Y - sumX2 * sumX3 * sumXY) / denominator;

    return List<double>.generate(n, (i) => rrIntervals[i] - (a + b * (i - n / 2) / n + c * (i - n / 2) / n * (i - n / 2) / n));
  }


  List<double> detrendSmooth(List<double> rrIntervals, int windowSize) {
    List<double> smoothed = [];
    for (int i = 0; i < rrIntervals.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - windowSize; j <= i + windowSize; j++) {
        if (j >= 0 && j < rrIntervals.length) {
          sum += rrIntervals[j];
          count++;
        }
      }
      smoothed.add(rrIntervals[i] - (sum / count));
    }
    return smoothed;
  }



}