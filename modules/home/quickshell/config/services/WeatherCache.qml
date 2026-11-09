pragma Singleton
import QtQuick

QtObject {
  property var report: null
  property var dailyForecastReport: null
  property var airQualityReport: null
  property string label: ""
  property string barTempC: ""
  property string barTempUnit: "°C"
  property string barGlyph: ""
}
