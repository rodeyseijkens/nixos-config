.pragma library

// English words quick add recognizes. QuickAddParser.js matches them in
// lowercase.

var WEEKDAYS = [
  ["sunday", "sun"],
  ["monday", "mon"],
  ["tuesday", "tues", "tue"],
  ["wednesday", "wed"],
  ["thursday", "thurs", "thur", "thu"],
  ["friday", "fri"],
  ["saturday", "sat"]
]

// Short forms that are also ordinary words only count as a weekday when
// context makes that reading clear.
var AMBIGUOUS_WEEKDAYS = ["sun", "sat", "wed"]

var MONTHS = [
  ["january"], ["february"], ["march"], ["april"], ["may"], ["june"],
  ["july"], ["august"], ["september"], ["october"], ["november"], ["december"]
]
var MONTHS_EN_SHORT = [["jan"], ["feb"], ["mar"], ["apr"], [], ["jun"], ["jul"], ["aug"],
  ["sept", "sep"], ["oct"], ["nov"], ["dec"]]

// Numbers written out, for "in two hours". A ten takes a digit after it:
// "twenty-five" and "twenty five" both work.
var EN_DIGITS = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
var TEENS = ["ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
  "eighteen", "nineteen"]
var EN_TENS = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
var NUMBER_WORDS = {
  "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
  "eight": 8, "nine": 9,
  "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
  "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
  "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
  "eighty": 80, "ninety": 90
}

// An hour written out, only after "at": "at three".
var EN_HOURS = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve"]

var MINUTE_UNITS = ["minutes", "minute", "mins", "min", "m"]
var HOUR_UNITS = ["hours", "hour", "hrs", "hr", "h"]
var DAY_UNITS = ["days", "day", "d"]
var WEEK_UNITS = ["weeks", "week", "wks", "wk", "w"]
var MONTH_UNITS = ["months", "month"]

// Where a day part starts, in minutes after midnight. A phrase in
// DAY_PART_PHRASES always counts; a bare word only right after a day
// ("friday morning"), so "Morning run" keeps its title.
var DAY_PART_START = { morning: 9 * 60, afternoon: 14 * 60, evening: 19 * 60 }
var DAY_PART_PHRASES = {
  morning: ["this morning", "in the morning"],
  afternoon: ["this afternoon", "in the afternoon"],
  evening: ["this evening", "in the evening", "tonight", "tonite", "at night"]
}
var DAY_PART_WORDS = {
  morning: ["morning"],
  afternoon: ["afternoon"],
  evening: ["evening", "night"]
}

// Repeats use the event form's presets. "Every monday" is read with the
// weekday, see EVERY_WORDS.
var REPEAT_PHRASES = {
  daily: ["every day", "everyday", "each day", "daily"],
  weekdays: ["every weekday", "every workday", "weekdays"],
  weekly: ["every week", "each week", "weekly"],
  monthlyDate: ["every month", "each month", "of every month", "of each month", "monthly"],
  yearly: ["every year", "each year", "yearly", "annually"]
}
// As the first word these name the event ("Weekly review"), not a repeat.
var REPEAT_TITLE_WORDS = ["daily", "weekly", "monthly", "yearly"]
// Before a weekday, a weekly repeat on that day: "every monday".
var EVERY_WORDS = ["every", "each"]
// Before a weekday in the plural, the same: "on mondays".
var PLURAL_DAY_WORDS = ["on"]
