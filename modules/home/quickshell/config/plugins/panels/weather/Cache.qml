pragma Singleton
import QtQuick

// Cache the panel's bulky forecast payloads across Loader teardown/reload.
// Current conditions for the bar belong to WeatherService instead.
QtObject {
  property var report: null
  property var dailyForecastReport: null
  property var airQualityReport: null
  property string label: ""
}
